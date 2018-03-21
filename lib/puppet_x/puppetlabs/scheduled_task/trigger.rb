# @api private
module PuppetX
module PuppetLabs
module ScheduledTask

module Trigger
  class Duration
    # From https://msdn.microsoft.com/en-us/library/windows/desktop/aa381850(v=vs.85).aspx
    # https://en.wikipedia.org/wiki/ISO_8601#Durations
    #
    # The format for this string is PnYnMnDTnHnMnS, where nY is the number of years, nM is the number of months,
    # nD is the number of days, 'T' is the date/time separator, nH is the number of hours, nM is the number of minutes,
    # and nS is the number of seconds (for example, PT5M specifies 5 minutes and P1M4DT2H5M specifies one month,
    # four days, two hours, and five minutes)
    def self.to_hash(duration)
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

    def self.hash_to_seconds(value)
      return 0 if value.nil?
      time = 0
      # Note - the Year and Month calculations are approximate
      time = time + value[:year].to_i   * (365.2422 * 24 * 60**2)      unless value[:year].nil?
      time = time + value[:month].to_i  * (365.2422 * 2 * 60**2)       unless value[:month].nil?
      time = time + value[:day].to_i    * 24 * 60**2                   unless value[:day].nil?
      time = time + value[:hour].to_i   * 60**2                        unless value[:hour].nil?
      time = time + value[:minute].to_i * 60                           unless value[:minute].nil?
      time = time + value[:second].to_i                                unless value[:second].nil?

      time.to_i
    end

    def self.to_minutes(value)
      return 0 if value.nil?
      return 0 unless value.is_a?(String)
      return 0 if value.empty?

      duration = hash_to_seconds(to_hash(value))

      duration / 60
    end
  end

  def string_to_int(value)
    return 0 if value.nil?
    return value if value.is_a?(Numeric)
    raise ArgumentError.new('value must be a String') unless value.is_a?(String)

    value.to_i
  end
  module_function :string_to_int

  def string_to_date(value)
    return nil if value.nil?
    raise ArgumentError.new('value must be a String') unless value.is_a?(String)
    return nil if value.empty?

    DateTime.parse(value)
  end
  module_function :string_to_date

  def iso8601_datetime(year, month, day, hour, minute)
    DateTime.new(year, month, day, hour, minute, 0).iso8601
  end
  module_function :iso8601_datetime

  # TASK_TRIGGER structure approximated as Ruby hash
  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa383618(v=vs.85).aspx
  class V1
    # Used for validating a trigger hash from Puppet
    ValidKeys = [
      'end_day',
      'end_month',
      'end_year',
      'flags',
      'minutes_duration',
      'minutes_interval',
      'random_minutes_interval',
      'start_day',
      'start_hour',
      'start_minute',
      'start_month',
      'start_year',
      'trigger_type',
      'type'
    ]

    ValidTypeKeys = [
        'days_interval',
        'weeks_interval',
        'days_of_week',
        'months',
        'days',
        'weeks'
    ]

    # canonicalize given trigger hash
    # throws errors if hash structure is invalid
    # @returns original object with downcased keys
    def self.canonicalize_and_validate(hash)
      raise TypeError unless hash.is_a?(Hash)
      hash = downcase_keys(hash)

      invalid_keys = hash.keys - ValidKeys
      raise ArgumentError.new("Invalid trigger keys #{invalid_keys}") unless invalid_keys.empty?

      if hash.keys.include?('type')
        type_hash = hash['type']
        raise ArgumentError.new("'type' must be a hash") unless type_hash.is_a?(Hash)
        invalid_keys = type_hash.keys - ValidTypeKeys
        raise ArgumentError.new("Invalid trigger type keys #{invalid_keys}") unless invalid_keys.empty?
      end

      hash
    end

    # iTrigger is a COM ITrigger instance
    def self.from_iTrigger(iTrigger)
      require 'puppet/util/windows/taskscheduler' # Needed for the WIN32::ScheduledTask flag constants
      trigger_flags = 0
      trigger_flags = trigger_flags | Win32::TaskScheduler::TASK_TRIGGER_FLAG_HAS_END_DATE unless iTrigger.Endboundary.empty?
      # There is no corresponding setting for the V1 flag TASK_TRIGGER_FLAG_KILL_AT_DURATION_END
      trigger_flags = trigger_flags | Win32::TaskScheduler::TASK_TRIGGER_FLAG_DISABLED unless iTrigger.Enabled

      start_boundary = Trigger.string_to_date(iTrigger.StartBoundary)
      end_boundary = Trigger.string_to_date(iTrigger.EndBoundary)

      v1trigger = {
        'start_year'              => start_boundary.year,
        'start_month'             => start_boundary.month,
        'start_day'               => start_boundary.day,
        'end_year'                => end_boundary ? end_boundary.year : 0,
        'end_month'               => end_boundary ? end_boundary.month : 0,
        'end_day'                 => end_boundary ? end_boundary.day : 0,
        'start_hour'              => start_boundary.hour,
        'start_minute'            => start_boundary.minute,
        'minutes_duration'        => Duration.to_minutes(iTrigger.Repetition.Duration),
        'minutes_interval'        => Duration.to_minutes(iTrigger.Repetition.Interval),
        'flags'                   => trigger_flags,
        'random_minutes_interval' => Trigger.string_to_int(iTrigger.Randomdelay)
      }

      case iTrigger.ole_type.to_s
        when 'ITimeTrigger'
          v1trigger['trigger_type'] = :TASK_TIME_TRIGGER_ONCE
          v1trigger['type'] = { 'once' => nil }
        when 'IDailyTrigger'
          v1trigger['trigger_type'] = :TASK_TIME_TRIGGER_DAILY
          v1trigger['type'] = {
            'days_interval' => Trigger.string_to_int(iTrigger.DaysInterval)
          }
        when 'IWeeklyTrigger'
          v1trigger['trigger_type'] = :TASK_TIME_TRIGGER_WEEKLY
          v1trigger['type'] = {
            'weeks_interval' => Trigger.string_to_int(iTrigger.WeeksInterval),
            'days_of_week'   => Trigger.string_to_int(iTrigger.DaysOfWeek)
          }
        when 'IMonthlyTrigger'
          v1trigger['trigger_type'] = :TASK_TIME_TRIGGER_MONTHLYDATE
          v1trigger['type'] = {
            'days'   => Trigger.string_to_int(iTrigger.DaysOfMonth),
            'months' => Trigger.string_to_int(iTrigger.MonthsOfYear)
          }
        when 'IMonthlyDOWTrigger'
          v1trigger['trigger_type'] = :TASK_TIME_TRIGGER_MONTHLYDOW
          v1trigger['type'] = {
            'weeks'        => Trigger.string_to_int(iTrigger.WeeksOfMonth),
            'days_of_week' => Trigger.string_to_int(iTrigger.DaysOfWeek),
            'months'       => Trigger.string_to_int(iTrigger.MonthsOfYear)
          }
        else
          raise Error.new(_("Unknown trigger type %{type}") % { type: iTrigger.ole_type.to_s })
      end

      v1trigger
    end

    private

    # converts all keys to lowercase
    def self.downcase_keys(hash)
      rekeyed = hash.map do |k, v|
        [k.is_a?(String) ? k.downcase : k, v.is_a?(Hash) ? downcase_keys(v) : v]
      end
      Hash[ rekeyed ]
    end

  end

  class V2
    V1_TYPE_MAP =
    {
      :TASK_TIME_TRIGGER_DAILY => TaskScheduler2::TASK_TRIGGER_DAILY,
      :TASK_TIME_TRIGGER_WEEKLY => TaskScheduler2::TASK_TRIGGER_WEEKLY,
      :TASK_TIME_TRIGGER_MONTHLYDATE => TaskScheduler2::TASK_TRIGGER_MONTHLY,
      :TASK_TIME_TRIGGER_MONTHLYDOW => TaskScheduler2::TASK_TRIGGER_MONTHLYDOW,
      :TASK_TIME_TRIGGER_ONCE => TaskScheduler2::TASK_TRIGGER_TIME,
    }.freeze

    def self.type_from_v1type(v1type)
      raise ArgumentError.new(_("Unknown V1 trigger Type %{type}") % { type: v1type }) unless V1_TYPE_MAP.keys.include?(v1type)
      V1_TYPE_MAP[v1type]
    end

    def self.append_v1trigger(definition, v1trigger)
      v1trigger = Trigger::V1.canonicalize_and_validate(v1trigger)

      trigger_type = type_from_v1type(v1trigger['trigger_type'])
      trigger_object = definition.Triggers.Create(trigger_type)
      trigger_settings = v1trigger['type']

      case v1trigger['trigger_type']
        when :TASK_TIME_TRIGGER_DAILY
          # https://msdn.microsoft.com/en-us/library/windows/desktop/aa446858(v=vs.85).aspx
          trigger_object.DaysInterval = trigger_settings['days_interval']

        when :TASK_TIME_TRIGGER_WEEKLY
          # https://msdn.microsoft.com/en-us/library/windows/desktop/aa384019(v=vs.85).aspx
          trigger_object.DaysOfWeek = trigger_settings['days_of_week']
          trigger_object.WeeksInterval = trigger_settings['weeks_interval']

        when :TASK_TIME_TRIGGER_MONTHLYDATE
          # https://msdn.microsoft.com/en-us/library/windows/desktop/aa382062(v=vs.85).aspx
          trigger_object.DaysOfMonth = trigger_settings['days']
          trigger_object.Monthsofyear = trigger_settings['months']

        when :TASK_TIME_TRIGGER_MONTHLYDOW
          # https://msdn.microsoft.com/en-us/library/windows/desktop/aa382055(v=vs.85).aspx
          trigger_object.DaysOfWeek = trigger_settings['days_of_week']
          trigger_object.Monthsofyear = trigger_settings['months']
          trigger_object.Weeksofmonth = trigger_settings['weeks']
      end

      # Values for all Trigger Types
      trigger_object.Repetition.Interval = "PT#{v1trigger['minutes_interval']}M" unless v1trigger['minutes_interval'].nil? || v1trigger['minutes_interval'].zero?
      trigger_object.Repetition.Duration = "PT#{v1trigger['minutes_duration']}M" unless v1trigger['minutes_duration'].nil? || v1trigger['minutes_duration'].zero?
      trigger_object.StartBoundary = Trigger.iso8601_datetime(v1trigger['start_year'],
                                                              v1trigger['start_month'],
                                                              v1trigger['start_day'],
                                                              v1trigger['start_hour'],
                                                              v1trigger['start_minute']
      )

      v1trigger
    end
  end
end
end
end
end
