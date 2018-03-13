# @api private
module PuppetX
module PuppetLabs
module ScheduledTask

module Trigger
  # From https://msdn.microsoft.com/en-us/library/windows/desktop/aa381850(v=vs.85).aspx
  # https://en.wikipedia.org/wiki/ISO_8601#Durations
  #
  # The format for this string is PnYnMnDTnHnMnS, where nY is the number of years, nM is the number of months,
  # nD is the number of days, 'T' is the date/time separator, nH is the number of hours, nM is the number of minutes,
  # and nS is the number of seconds (for example, PT5M specifies 5 minutes and P1M4DT2H5M specifies one month,
  # four days, two hours, and five minutes)
  def duration_to_hash(duration)
    regex = /^P((?'year'\d+)Y)?((?'month'\d+)M)?((?'day'\d+)D)?(T((?'hour'\d+)H)?((?'minute'\d+)M)?((?'second'\d+)S)?)?$/

    matches = regex.match(duration)
    return nil if matches.nil?

    {
      :year => matches['year'],
      :month => matches['month'],
      :day => matches['day'],
      :minute => matches['minute'],
      :hour => matches['hour'],
      :second => matches['second'],
    }
  end
  module_function :duration_to_hash

end
end
end
end
