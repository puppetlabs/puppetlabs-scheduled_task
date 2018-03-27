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

  class V1
  class Day
    # https://msdn.microsoft.com/en-us/library/windows/desktop/aa384014(v=vs.85).aspx
    TASK_SUNDAY       = 0x1
    TASK_MONDAY       = 0x2
    TASK_TUESDAY      = 0x4
    TASK_WEDNESDAY    = 0x8
    TASK_THURSDAY     = 0x10
    TASK_FRIDAY       = 0x20
    TASK_SATURDAY     = 0x40

    DAY_CONST_MAP = {
      'sun'   => TASK_SUNDAY,
      'mon'   => TASK_MONDAY,
      'tues'  => TASK_TUESDAY,
      'wed'   => TASK_WEDNESDAY,
      'thurs' => TASK_THURSDAY,
      'fri'   => TASK_FRIDAY,
      'sat'   => TASK_SATURDAY,
    }.freeze

    def self.names
      @names ||= DAY_CONST_MAP.keys.freeze
    end

    def self.values
      @values ||= DAY_CONST_MAP.values.freeze
    end

    def self.names_to_bitmask(day_names)
      day_names = [day_names].flatten
      invalid_days = day_names - DAY_CONST_MAP.keys
      raise ArgumentError.new("Days_of_week value #{invalid_days.join(', ')} is invalid. Expected sun, mon, tue, wed, thu, fri or sat.") unless invalid_days.empty?

      day_names.inject(0) { |bitmask, day| bitmask |= DAY_CONST_MAP[day] }
    end

    def self.bitmask_to_names(bitmask)
      bitmask = Integer(bitmask)
      if (bitmask < 0 || bitmask > 0b1111111)
        raise ArgumentError.new("bitmask must be specified as an integer from 0 to #{0b1111111.to_s(10)}")
      end

      DAY_CONST_MAP.values.each_with_object([]) do |day, names|
        names << DAY_CONST_MAP.key(day) if bitmask & day != 0
      end
    end
  end
  end

  class V1
  class Days
    def self.indexes_to_bitmask(day_indexes)
      day_indexes = [day_indexes].flatten.map do |m|
        # The special "day" of 'last' is represented by day "number"
        # 32. 'last' has the special meaning of "the last day of the
        # month", no matter how many days there are in the month.
        # raises if unable to convert
        m.is_a?(String) && m.casecmp('last') == 0 ? 32 : Integer(m)
      end

      invalid_days = day_indexes.find_all { |i| !i.between?(1, 32) }
      if !invalid_days.empty?
        raise ArgumentError.new("Day indexes value #{invalid_days.join(', ')} is invalid. Integers must be in the range 1-31, or 'last'")
      end

      day_indexes.inject(0) { |bitmask, day_index| bitmask |= 1 << day_index - 1 }
    end

    def self.bitmask_to_indexes(bitmask)
      bitmask = Integer(bitmask)
      max_mask = 0b11111111111111111111111111111111
      if (bitmask < 0 || bitmask > max_mask)
        raise ArgumentError.new("bitmask must be specified as an integer from 0 to #{max_mask.to_s(10)}")
      end

      (0..31).select do |bit_index|
        bit_to_check = 1 << bit_index
        # given position is set in the bitmask
        (bitmask & bit_to_check) == bit_to_check
      end.map do |bit_index|
        # Day 32 has the special meaning of "the last day of the
        # month", no matter how many days there are in the month.
        bit_index == 31 ? 'last' : bit_index + 1
      end
    end
  end
  end

  class V1
  class Month
    # https://msdn.microsoft.com/en-us/library/windows/desktop/aa381918(v=vs.85).aspx
    TASK_JANUARY      = 0x1
    TASK_FEBRUARY     = 0x2
    TASK_MARCH        = 0x4
    TASK_APRIL        = 0x8
    TASK_MAY          = 0x10
    TASK_JUNE         = 0x20
    TASK_JULY         = 0x40
    TASK_AUGUST       = 0x80
    TASK_SEPTEMBER    = 0x100
    TASK_OCTOBER      = 0x200
    TASK_NOVEMBER     = 0x400
    TASK_DECEMBER     = 0x800

    MONTHNUM_CONST_MAP = {
      1  => TASK_JANUARY,
      2  => TASK_FEBRUARY,
      3  => TASK_MARCH,
      4  => TASK_APRIL,
      5  => TASK_MAY,
      6  => TASK_JUNE,
      7  => TASK_JULY,
      8  => TASK_AUGUST,
      9  => TASK_SEPTEMBER,
      10 => TASK_OCTOBER,
      11 => TASK_NOVEMBER,
      12 => TASK_DECEMBER,
    }.freeze

    def self.indexes_to_bitmask(month_indexes)
      month_indexes = [month_indexes].flatten.map { |m| Integer(m) rescue m }
      invalid_months = month_indexes - MONTHNUM_CONST_MAP.keys
      raise ArgumentError.new('Month must be specified as an integer in the range 1-12') unless invalid_months.empty?

      month_indexes.inject(0) { |bitmask, month_index| bitmask |= MONTHNUM_CONST_MAP[month_index] }
    end

    def self.bitmask_to_indexes(bitmask)
      bitmask = Integer(bitmask)
      if (bitmask < 0 || bitmask > 0b111111111111)
        raise ArgumentError.new("bitmask must be specified as an integer from 0 to #{0b111111111111.to_s(10)}")
      end

      MONTHNUM_CONST_MAP.values.each_with_object([]) do |day, indexes|
        indexes << MONTHNUM_CONST_MAP.key(day) if bitmask & day != 0
      end
    end
  end
  end

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
    class Type
      # https://msdn.microsoft.com/en-us/library/windows/desktop/aa383915%28v=vs.85%29.aspx
      TASK_TRIGGER_EVENT                 = 0
      TASK_TRIGGER_TIME                  = 1
      TASK_TRIGGER_DAILY                 = 2
      TASK_TRIGGER_WEEKLY                = 3
      TASK_TRIGGER_MONTHLY               = 4
      TASK_TRIGGER_MONTHLYDOW            = 5
      TASK_TRIGGER_IDLE                  = 6
      TASK_TRIGGER_REGISTRATION          = 7
      TASK_TRIGGER_BOOT                  = 8
      TASK_TRIGGER_LOGON                 = 9
      TASK_TRIGGER_SESSION_STATE_CHANGE  = 11
    end

    V1_TYPE_MAP =
    {
      :TASK_TIME_TRIGGER_DAILY => Type::TASK_TRIGGER_DAILY,
      :TASK_TIME_TRIGGER_WEEKLY => Type::TASK_TRIGGER_WEEKLY,
      :TASK_TIME_TRIGGER_MONTHLYDATE => Type::TASK_TRIGGER_MONTHLY,
      :TASK_TIME_TRIGGER_MONTHLYDOW => Type::TASK_TRIGGER_MONTHLYDOW,
      :TASK_TIME_TRIGGER_ONCE => Type::TASK_TRIGGER_TIME,
    }.freeze

    def self.type_from_v1type(v1type)
      raise ArgumentError.new(_("Unknown V1 trigger Type %{type}") % { type: v1type }) unless V1_TYPE_MAP.keys.include?(v1type)
      V1_TYPE_MAP[v1type]
    end

    def self.append_v1trigger(definition, v1trigger)
      v1trigger = Trigger::V1.canonicalize_and_validate(v1trigger)

      trigger_type = type_from_v1type(v1trigger['trigger_type'])
      iTrigger = definition.Triggers.Create(trigger_type)
      trigger_settings = v1trigger['type']

      case trigger_type
        when Type::TASK_TRIGGER_DAILY
          # https://msdn.microsoft.com/en-us/library/windows/desktop/aa446858(v=vs.85).aspx
          iTrigger.DaysInterval = trigger_settings['days_interval']

        when Type::TASK_TRIGGER_WEEKLY
          # https://msdn.microsoft.com/en-us/library/windows/desktop/aa384019(v=vs.85).aspx
          iTrigger.DaysOfWeek = trigger_settings['days_of_week']
          iTrigger.WeeksInterval = trigger_settings['weeks_interval']

        when Type::TASK_TRIGGER_MONTHLY
          # https://msdn.microsoft.com/en-us/library/windows/desktop/aa382062(v=vs.85).aspx
          iTrigger.DaysOfMonth = trigger_settings['days']
          iTrigger.Monthsofyear = trigger_settings['months']

        when Type::TASK_TRIGGER_MONTHLYDOW
          # https://msdn.microsoft.com/en-us/library/windows/desktop/aa382055(v=vs.85).aspx
          iTrigger.DaysOfWeek = trigger_settings['days_of_week']
          iTrigger.Monthsofyear = trigger_settings['months']
          iTrigger.Weeksofmonth = trigger_settings['weeks']
      end

      # Values for all Trigger Types
      iTrigger.RandomDelay         = "PT#{v1trigger['random_minutes_interval']}M" unless v1trigger['random_minutes_interval'].nil?   || v1trigger['random_minutes_interval'].zero?
      iTrigger.Repetition.Interval = "PT#{v1trigger['minutes_interval']}M" unless v1trigger['minutes_interval'].nil? || v1trigger['minutes_interval'].zero?
      iTrigger.Repetition.Duration = "PT#{v1trigger['minutes_duration']}M" unless v1trigger['minutes_duration'].nil? || v1trigger['minutes_duration'].zero?
      iTrigger.StartBoundary = Trigger.iso8601_datetime(v1trigger['start_year'],
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
