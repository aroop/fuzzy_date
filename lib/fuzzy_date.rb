################################################################################
#
#  Routines to manage the FuzzyDate Class. There is also an extension to the 
#  ActiveRecord::Base class to provide an 'acts_as_fuzzy_date' class method.
#--
#  Copyright (c) Clive Andrews / Reality Bites 2008, 2009, 2010
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
# version 20100224-1
# ++
#  
################################################################################
require 'date'


# A fuzzy date is a representation of a date which may well be incomplete
# or imprecise. You can enter the exact date or for example just the day of
# the week or the year or a combination thereof. One can also add the Circa
# prefix to any date. The FuzzyDate object is immutable so if you wish to 
# change a FuzzyDate value it is neccessary to create a new FuzzyDate.
class FuzzyDate
  
  include Comparable
  
  # overload the Date class to modify its parsing routine a little
  #
  class FDate < Date # :nodoc:
    def self._parse_year(str, e) 
      if str.sub!(/(\d{3,})\b/in, ' ')
        e.year = $1.to_i
        true
      else
        super(str,e)
      end
    end
  end # FDate
  
  # create a new FuzzyDate object. There are no checks here to 
  # validate if the date is valid or not.. eg there is no check 
  # that the day of the week actually corresponds to the actual
  # date if completely specified.
  def initialize(year=nil,month=nil,day=nil,wday=nil,circa=nil)
    raise "FuzzyDate: invalid month"   if month && ((month>12) || (month<1))
    raise "FuzzyDate: invalid day"     if day   && ((day>31)   || (day<1))
    raise "FuzzyDate: invalid weekday" if wday  && ((wday>6)   || (wday<0))
    raise "FuzzyDate: year too big !"  if year  && (year.abs > 99999999999 )
    @year  = year && year.abs
    @month = month
    @day   = day
    @wday  = wday
    @circa = circa
    @bce   = year && (year.to_i < 0)
  end
  
  # returns an integer representing the day of the week, 0..6
  # with Sunday=0. returns nil if not known. 
  def wday 
    if !@wday && complete? && (@year > 0)
      to_date.wday
    else
      @wday
    end
  end
  
  # returns the day of the month ( 1..n ). returns nil if not known.
  def day
    @day
  end
  
  # returns the month number (1..12). returns nil if not known.
  def month
    @month
  end
  
  # returns the year number (including century)
  def year
    @year
  end
  
  # is the date approximate ?
  def circa?
    @circa
  end
  
  # is the date before the year zero.
  def bce?
    @bce
  end
  
  #  return an integer representing only the month and day
  def birthday
    month * 100 + day if month && day
  end
  
  # is the date complete
  def complete?
    year && (month  && month < 13) && (day  && day < 32)
  end
  
  # is the date completely unknown
  def unknown?
    !@year && !@month && !@day && !@wday
  end
  
  # convert to integer format
  def to_i
    to_db
  end
  
  # convert the fuzzy date into a format which can be stored in a database. The
  # storage format is integer format (BIGINT) with digits having the following positional
  # significance:
  #
  #   (-/+)  (YYYYYYYYYYY.....Y)MMDDd[01][01]
  #
  #   where + is AD or CE
  #         - is BC or BCE
  #         1 at end = circa or C otherwise 0
  #         1 at 2nd from end  = year unknown - otherwise missing year = year 0
  #         YYYYY is the year number 0 or missing  = year absent OR value is unknown
  #         MM    is the month number or 13 for unknown
  #         DD    is the day of the month or 32 for unknown
  #         d     is the day of the week where 8 = unknown, 1=Sunday .. 7=Saturday
  #
  #
  #   this wierd format has been chosen to allow sorting within the database and to
  #   avoid leading zeros containing information from being stripped from the representation.
  #
  #   save in a  mysql database in format BIGINT 
  #
  def to_db
    str = ''
    str= str + (@year > 0 ? @year.to_s : '') if @year
    str= str + (@month ? "%02d" % @month.to_s : '13')
    str= str + (@day ? "%02d" % @day.to_s : '32')
    str= str + (@wday ? (@wday+1).to_s : '8')
    str= str + (@year  ? '0' : '1')
    str= str + (@circa  ? '1' : '0')
    i = str.to_i
    i = -i if @bce
    i
  end
  
  # create a new FuzzyDate object from the database formatted
  # integer.
  def self.new_from_db(i)
    return nil unless i
    str = i.to_s
    return nil if str == '0'
    bce = false
    raise "Invalid Fuzzy Time String - #{str}" unless str =~/^[+-]?\d{6,}$/
    str.sub!(/^-/){|m| bce= true;""} 
    str = ("000000" + str)[-7,7] if str.length < 7
    circa   =  (str[-1,1] == '1')
    year    =  (str[-2,1] == '1' ? nil : 0)
    wday    = str[-3,1].to_i - 1
    day     = str[-5,2].to_i
    month   = str[-7,2].to_i
    wday    = nil if ((wday<0) || (wday>6))
    day     = nil if ((day==0) || (day>31))
    month   = nil if ((month==0) || (month > 12))
    year    = (str[0..-8].to_i > 0 ? str[0..-8].to_i : year )
    year = -year if year && bce
    new(year,month,day,wday,circa)
  end
  
  # convert to a human readable string
  def to_s
    if unknown?
      str = "unknown"
    else
      "#{year}-#{month}-#{day}"
      #str = ""
      #str = "circa "                        if circa?
      #str+= FDate::DAYNAMES[wday]    + " "  if wday
      #str+= day.to_s + " "                  if day
      #str+= FDate::MONTHNAMES[month] + " "  if month
      #str+= year.to_s                       if year
      #str += " bce"                         if bce?
      #str.strip
    end
  end
  
  # if the date is complete then return a regular
  # Date object
  def to_date
    return nil unless complete?
    Date.new(@year,@month,@day)
  end
  
  # create a FuzzyDate object from a Date object
  def self.new_from_date( date)
    new(date.year,date.month,date.day)
  end
  
  # create a new date object by parsing a string
  def self.parse( str )
    
    return unless str && str.length > 0
    
    continue = true
    circa    = false
    bce      = false
    unknown  = false
    
    #filter out 'c' or 'circa'
    str.sub!(/CIRCA/i){|m| circa=true;continue=nil} if continue
    str.sub!(/^CA /i){|m| circa=true;continue=nil} if continue
    str.sub!(/^C /i){|m| circa=true;continue=nil} if continue
    str.sub!(/ABOUT/i){|m| circa=true;continue=nil} if continue
    str.sub!(/AROUND/i){|m| circa=true;continue=nil} if continue
    str.sub!(/ROUND/i){|m| circa=true;continue=nil} if continue
    str.sub!(/APPROX/i){|m| circa=true;continue=nil} if continue
    str.sub!(/APPROXIMATELY/i){|m| circa=true;continue=nil} if continue
    
    #filter out 'bc' 'bce'
    continue = true
    str.sub!(/BCE/i){|m| bce=true;continue=nil}
    str.sub!(/BC/i){|m| bce=true;continue=nil} if continue
    
    #filter out 'unknown'
    continue = true
    str.sub!(/UNKNOWN/i){|m| unknown=true;continue=nil}
    
    # if date is unknown then return an empty FuzzyDate
    return self.new if unknown
    
    # now try to parse the remaining string with the Date parse
    # method.
    
    components= FDate._parse(str,false)
    year  = components[:year]
    month = components[:mon]
    day   = components[:mday]
    wday  = components[:wday]
    
    # fudge the results a bit
    year,day = day,nil if (day && !month && !year) || (!year && (day.to_i > 31))
    if year && year < 0 
      year = year.abs
      bce  = true
    end
    
    year = -year if bce
    self.new(year,month,day,wday,circa)
  end
  
  def <=>(other) self.to_db <=> other.to_db end
  
end #class FuzzyDate

# add an acts_as_fuzzy_date helper to ActiveRecord to define
# a table field as a FuzzyDate.
#
# eg:
#
#       require 'fuzzy_date'
#
#       class HistoricalPerson < ActiveRecord::Base
#           acts_as_fuzzy_date : birth_date, death_date
#       end
#
if defined? ActiveRecord::Base
  class ActiveRecord::Base
    class << self
      def acts_as_fuzzy_date(*args)
        args.each do |name|
          str =<<-EOF
          def #{name}
             FuzzyDate.new_from_db(self['#{name}'])
          end
    
          def #{name}=(s)
             if s.kind_of? String
                if s.present? && s.include?('-')
                  date_fields = s.split('-')
                  self['#{name}'] = FuzzyDate.new(date_fields[0].try(:to_i), date_fields[1].try(:to_i), date_fields[2].try(:to_i)).to_db
                else
                  self['#{name}'] = FuzzyDate.parse(s).to_db unless s.strip.empty?
                end
             elsif s.kind_of? FuzzyDate
                 self['#{name}']=s.to_db
             elsif !s
                 self['#{name}'] = nil
             end
          end
EOF
          class_eval str
        end
      end
    end
  end
end
