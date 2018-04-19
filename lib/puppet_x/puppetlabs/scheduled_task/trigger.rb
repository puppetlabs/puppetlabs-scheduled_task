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

  class V1
  class Occurrence
    # https://msdn.microsoft.com/en-us/library/windows/desktop/aa381950(v=vs.85).aspx
    TASK_FIRST_WEEK   = 1
    TASK_SECOND_WEEK  = 2
    TASK_THIRD_WEEK   = 3
    TASK_FOURTH_WEEK  = 4
    TASK_LAST_WEEK    = 5

    WEEK_OF_MONTH_CONST_MAP = {
      'first'  => TASK_FIRST_WEEK,
      'second' => TASK_SECOND_WEEK,
      'third'  => TASK_THIRD_WEEK,
      'fourth' => TASK_FOURTH_WEEK,
      'last'   => TASK_LAST_WEEK,
    }.freeze

    def self.constant_to_name(constant)
      WEEK_OF_MONTH_CONST_MAP.key(constant)
    end

    def self.name_to_constant(name)
      WEEK_OF_MONTH_CONST_MAP[name]
    end
  end
  end

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa383618(v=vs.85).aspx
  class V1
  class Flag
    TASK_TRIGGER_FLAG_HAS_END_DATE         = 0x1
    TASK_TRIGGER_FLAG_KILL_AT_DURATION_END = 0x2
    TASK_TRIGGER_FLAG_DISABLED             = 0x4
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

   ValidManifestKeys = [
      'index',
      'enabled',
      'schedule',
      'start_date',
      'start_time',
      'every',
      'months',
      'on',
      'which_occurrence',
      'day_of_week',
      'minutes_interval',
      'minutes_duration'
    ].freeze

    ScheduleNameDefaultsMap = {
      'daily' => :TASK_TIME_TRIGGER_DAILY,
      'weekly' => :TASK_TIME_TRIGGER_WEEKLY,
      # NOTE: monthly uses context to determine MONTHLYDATE or MONTHLYDOW
      'monthly' => :TASK_TIME_TRIGGER_MONTHLYDATE,
      'once' => :TASK_TIME_TRIGGER_ONCE,
    }.freeze

    ValidManifestScheduleKeys = ScheduleNameDefaultsMap.keys.freeze

    def self.normalized_date(year, month, day)
      Date.new(year, month, day).strftime('%Y-%-m-%-d')
    end

    def self.normalized_time(hour, minute)
      Time.parse("#{hour}:#{minute}").strftime('%H:%M')
    end
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
      trigger_flags = 0
      trigger_flags = trigger_flags | Flag::TASK_TRIGGER_FLAG_HAS_END_DATE unless iTrigger.Endboundary.empty?
      # There is no corresponding setting for the V1 flag TASK_TRIGGER_FLAG_KILL_AT_DURATION_END
      trigger_flags = trigger_flags | Flag::TASK_TRIGGER_FLAG_DISABLED unless iTrigger.Enabled

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

    def self.default_trigger_settings_for(type = 'once')
      case type
      when 'daily'
        { 'days_interval' => 1 }
      when 'weekly'
        {
          'days_of_week'   => Day.names_to_bitmask(Day.names),
          'weeks_interval' => 1
        }
      when 'monthly'
        { 'months' => Month.indexes_to_bitmask((1..12).to_a) }
      end
    end

    def self.default_trigger_for(type = 'once')
      now = Time.now
      type_hash = default_trigger_settings_for(type)
      {
        'flags'                   => 0,
        'random_minutes_interval' => 0,
        'end_day'                 => 0,
        'end_year'                => 0,
        'minutes_interval'        => 0,
        'end_month'               => 0,
        'minutes_duration'        => 0,
        'start_year'              => now.year,
        'start_month'             => now.month,
        'start_day'               => now.day,
        'start_hour'              => now.hour,
        'start_minute'            => now.min,
        'trigger_type'            => ScheduleNameDefaultsMap[type],
      # 'once' has no specific settings, so 'type' should be omitted
      }.merge( type_hash.nil? ? {} : { 'type' => type_hash })
    end

    # canonicalize given trigger hash
    # throws errors if hash structure is invalid
    # does not throw errors when invalid types are specified
    # @returns original object with downcased keys
    def self.canonicalize_and_validate_manifest(manifest_hash)
      raise TypeError unless manifest_hash.is_a?(Hash)
      manifest_hash = downcase_keys(manifest_hash)

      # check for valid key usage
      invalid_keys = manifest_hash.keys - ValidManifestKeys
      raise ArgumentError.new("Unknown trigger option(s): #{Puppet::Parameter.format_value_for_display(invalid_keys)}") unless invalid_keys.empty?

      if !ValidManifestScheduleKeys.include?(manifest_hash['schedule'])
        raise ArgumentError.new("Unknown schedule type: #{manifest_hash["schedule"].inspect}")
      end

      # required fields
      %w{start_time}.each do |field|
        next if manifest_hash.key?(field)
        raise ArgumentError.new("Must specify '#{field}' when defining a trigger")
      end

      # specific setting rules for schedule types
      case manifest_hash['schedule']
      when 'monthly'
        if manifest_hash.key?('on')
          if manifest_hash.key?('day_of_week') || manifest_hash.key?('which_occurrence')
            raise ArgumentError.new("Neither 'day_of_week' nor 'which_occurrence' can be specified when creating a monthly date-based trigger")
          end
        elsif manifest_hash.key?('which_occurrence') || manifest_hash.key?('day_of_week')
          raise ArgumentError.new('which_occurrence cannot be specified as an array') if manifest_hash['which_occurrence'].is_a?(Array)

          %w{day_of_week which_occurrence}.each do |field|
            next if manifest_hash.key?(field)
            raise ArgumentError.new("#{field} must be specified when creating a monthly day-of-week based trigger")
          end
        else
          raise ArgumentError.new("Don't know how to create a 'monthly' schedule with the options: #{manifest_hash.keys.sort.join(', ')}")
        end
      when 'once'
        raise ArgumentError.new("Must specify 'start_date' when defining a one-time trigger") unless manifest_hash['start_date']
      end

      # duration set with / without interval
      if manifest_hash['minutes_duration']
        duration = Integer(manifest_hash['minutes_duration'])
        # defaults to -1 when unspecified
        interval = Integer(manifest_hash['minutes_interval'] || -1)
        if duration != 0 && duration <= interval
          raise ArgumentError.new('minutes_duration must be an integer greater than minutes_interval and equal to or greater than 0')
        end
      end

      # interval set with / without duration
      if manifest_hash['minutes_interval']
        interval = Integer(manifest_hash['minutes_interval'])
        # interval < 0
        if interval < 0
          raise ArgumentError.new('minutes_interval must be an integer greater or equal to 0')
        end

        # defaults to a day when unspecified
        duration = Integer(manifest_hash['minutes_duration'] || 1440)

        if interval > 0 && interval >= duration
          raise ArgumentError.new('minutes_interval cannot be set without minutes_duration also being set to a number greater than 0')
        end
      end

      if manifest_hash['start_date']
        min_date = Date.new(1753, 1, 1)
        start_date = Date.parse(manifest_hash['start_date'])
        raise ArgumentError.new("start_date must be on or after 1753-01-01") unless start_date >= min_date
      end

      manifest_hash
    end

    # manifest_hash is a hash created from a manifest
    def self.from_manifest_hash(manifest_hash)
      manifest_hash = canonicalize_and_validate_manifest(manifest_hash)

      trigger = default_trigger_for(manifest_hash['schedule'])

      if manifest_hash['enabled'] == false
        trigger['flags'] |= Flag::TASK_TRIGGER_FLAG_DISABLED
      else
        trigger['flags'] &= ~Flag::TASK_TRIGGER_FLAG_DISABLED
      end

      case manifest_hash['schedule']
      when 'daily'
        trigger['type']['days_interval'] = Integer(manifest_hash['every'] || 1)
      when 'weekly'
        trigger['type']['weeks_interval'] = Integer(manifest_hash['every'] || 1)

        days_of_week = manifest_hash['day_of_week'] || Day.names
        trigger['type']['days_of_week'] = Day.names_to_bitmask(days_of_week)
      when 'monthly'
        trigger['type']['months'] = Month.indexes_to_bitmask(manifest_hash['months'] || (1..12).to_a)

        if manifest_hash.keys.include?('on')
          trigger['trigger_type'] = :TASK_TIME_TRIGGER_MONTHLYDATE
          trigger['type']['days'] = Days.indexes_to_bitmask(manifest_hash['on'])
        elsif manifest_hash.keys.include?('which_occurrence') or manifest_hash.keys.include?('day_of_week')
          trigger['trigger_type']         = :TASK_TIME_TRIGGER_MONTHLYDOW
          trigger['type']['weeks']        = Occurrence.name_to_constant(manifest_hash['which_occurrence'])
          trigger['type']['days_of_week'] = Day.names_to_bitmask(manifest_hash['day_of_week'])
        end
      end

      integer_interval = -1
      if manifest_hash['minutes_interval']
        integer_interval = Integer(manifest_hash['minutes_interval'])
        trigger['minutes_interval'] = integer_interval
      end

      if manifest_hash['minutes_duration']
        trigger['minutes_duration'] = Integer(manifest_hash['minutes_duration'])
      end

      if integer_interval > 0 && !manifest_hash.key?('minutes_duration')
        minutes_in_day = 1440
        trigger['minutes_duration'] = minutes_in_day
      end

      if start_date = manifest_hash['start_date']
        start_date = Date.parse(start_date)
        trigger['start_year']  = start_date.year
        trigger['start_month'] = start_date.month
        trigger['start_day']   = start_date.day
      end

      start_time = Time.parse(manifest_hash['start_time'])
      trigger['start_hour']   = start_time.hour
      trigger['start_minute'] = start_time.min

      trigger
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
