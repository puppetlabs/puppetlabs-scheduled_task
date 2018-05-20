require 'time'

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

  def iso8601_datetime_to_local(value)
    return nil if value.nil?
    raise ArgumentError.new('value must be a String') unless value.is_a?(String)
    return nil if value.empty?

    # defaults to parsing as local with no timezone passed
    Time.parse(value).getlocal
  end
  module_function :iso8601_datetime_to_local

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
        {
          'months' => Month.indexes_to_bitmask((1..12).to_a),
          'days' => 0
        }
      end
    end

    def self.default_trigger_for(type = 'once')
      now = Time.now
      type_hash = default_trigger_settings_for(type)
      {
        'flags'                   => 0,
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

      # The start_time must be canonicalized to match the format that the rest of the code expects
      manifest_hash['start_time'] = Time.parse(manifest_hash['start_time']).strftime('%H:%M')

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
      manifest_hash['minutes_interval'] = interval if interval
      manifest_hash['minutes_duration'] = duration if duration

      if manifest_hash['start_date']
        min_date = Date.new(1753, 1, 1)
        start_date = Date.parse(manifest_hash['start_date'])
        raise ArgumentError.new("start_date must be on or after 1753-01-01") unless start_date >= min_date
        manifest_hash['start_date'] = start_date.strftime('%Y-%-m-%-d')
      end

      manifest_hash
    end

    # manifest_hash is a hash created from a manifest
    def self.from_manifest_hash(manifest_hash)
      manifest_hash = canonicalize_and_validate_manifest(manifest_hash)

      trigger = default_trigger_for(manifest_hash['schedule'])

      case manifest_hash['schedule']
      when 'daily'
        trigger['type']['days_interval'] = Integer(manifest_hash['every'] || 1)
      when 'weekly'
        trigger['type']['weeks_interval'] = Integer(manifest_hash['every'] || 1)

        days_of_week = manifest_hash['day_of_week'] || Day.names
        trigger['type']['days_of_week'] = Day.names_to_bitmask(days_of_week)
      when 'monthly'
        trigger['type']['months'] = Month.indexes_to_bitmask(manifest_hash['months'] || (1..12).to_a)

        if manifest_hash.key?('on')
          trigger['trigger_type'] = :TASK_TIME_TRIGGER_MONTHLYDATE
          trigger['type']['days'] = Days.indexes_to_bitmask(manifest_hash['on'])
        elsif  manifest_hash.key?('which_occurrence') || manifest_hash.key?('day_of_week')
          trigger['trigger_type']         = :TASK_TIME_TRIGGER_MONTHLYDOW
          trigger['type']['weeks']        = Occurrence.name_to_constant(manifest_hash['which_occurrence'])
          trigger['type']['days_of_week'] = Day.names_to_bitmask(manifest_hash['day_of_week'])
        end
      end

      manifest_hash['enabled'] == false ?
        trigger['flags'] |= Flag::TASK_TRIGGER_FLAG_DISABLED :
        trigger['flags'] &= ~Flag::TASK_TRIGGER_FLAG_DISABLED

      if manifest_hash['minutes_interval']
        trigger['minutes_interval'] = Integer(manifest_hash['minutes_interval'])

        if trigger['minutes_interval'] > 0 && !manifest_hash.key?('minutes_duration')
          trigger['minutes_duration'] = 1440 # one day in minutes
        end
      end

      if manifest_hash['minutes_duration']
        trigger['minutes_duration'] = Integer(manifest_hash['minutes_duration'])
      end

      # manifests specify datetime in the local timezone, same as V1 trigger
      datetime_string = "#{manifest_hash['start_date']} #{manifest_hash['start_time']}"
      # Time.parse always assumes local time
      local_manifest_date = Time.parse(datetime_string)

      # today has already been filled in to default trigger structure, only override if necessary
      if manifest_hash['start_date']
        trigger['start_year']   = local_manifest_date.year
        trigger['start_month']  = local_manifest_date.month
        trigger['start_day']    = local_manifest_date.day
      end
      trigger['start_hour']   = local_manifest_date.hour
      trigger['start_minute'] = local_manifest_date.min

      trigger
    end

    def self.to_manifest_hash(v1trigger)
      unless V2::V1_TYPE_MAP.keys.include?(v1trigger['trigger_type'])
        raise ArgumentError.new(_("Unknown trigger type %{type}") % { type: v1trigger['trigger_type'] })
      end

      manifest_hash = {}

      case v1trigger['trigger_type']
      when :TASK_TIME_TRIGGER_DAILY
        manifest_hash['schedule'] = 'daily'
        manifest_hash['every']    = v1trigger['type']['days_interval'].to_s
      when :TASK_TIME_TRIGGER_WEEKLY
        manifest_hash['schedule']    = 'weekly'
        manifest_hash['every']       = v1trigger['type']['weeks_interval'].to_s
        manifest_hash['day_of_week'] = Day.bitmask_to_names(v1trigger['type']['days_of_week'])
      when :TASK_TIME_TRIGGER_MONTHLYDATE
        manifest_hash['schedule'] = 'monthly'
        manifest_hash['months']   = Month.bitmask_to_indexes(v1trigger['type']['months'])
        manifest_hash['on']       = Days.bitmask_to_indexes(v1trigger['type']['days'])

      when :TASK_TIME_TRIGGER_MONTHLYDOW
        manifest_hash['schedule']         = 'monthly'
        manifest_hash['months']           = Month.bitmask_to_indexes(v1trigger['type']['months'])
        manifest_hash['which_occurrence'] = Occurrence.constant_to_name(v1trigger['type']['weeks'])
        manifest_hash['day_of_week']      = Day.bitmask_to_names(v1trigger['type']['days_of_week'])
      when :TASK_TIME_TRIGGER_ONCE
        manifest_hash['schedule'] = 'once'
      end

      # V1 triggers are local time already, same as manifest
      local_trigger_date = Time.local(
        v1trigger['start_year'],
        v1trigger['start_month'],
        v1trigger['start_day'],
        v1trigger['start_hour'],
        v1trigger['start_minute'],
        0
      )

      manifest_hash['start_date'] = local_trigger_date.strftime('%Y-%-m-%-d')
      manifest_hash['start_time'] = local_trigger_date.strftime('%H:%M')
      manifest_hash['enabled']    = v1trigger['flags'] & Flag::TASK_TRIGGER_FLAG_DISABLED == 0
      manifest_hash['minutes_interval'] = v1trigger['minutes_interval'] ||= 0
      manifest_hash['minutes_duration'] = v1trigger['minutes_duration'] ||= 0

      manifest_hash
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
  class WeeksOfMonth
    # https://msdn.microsoft.com/en-us/library/windows/desktop/aa380733(v=vs.85).aspx
    FIRST   = 0x01
    SECOND  = 0x02
    THIRD   = 0x04
    FOURTH  = 0x08
    LAST    = 0x10

    WEEK_OF_MONTH_CONST_MAP = {
      'first'  => FIRST,
      'second' => SECOND,
      'third'  => THIRD,
      'fourth' => FOURTH,
      'last'   => LAST,
    }.freeze

    def self.names_to_bitmask(week_names)
      week_names = [week_names].flatten
      invalid_weeks = week_names - WEEK_OF_MONTH_CONST_MAP.keys
      raise ArgumentError.new("week_names value #{invalid_weeks.join(', ')} is invalid. Expected first, second, third, fourth or last.") unless invalid_weeks.empty?

      week_names.inject(0) { |bitmask, day| bitmask |= WEEK_OF_MONTH_CONST_MAP[day] }
    end

    def self.bitmask_to_names(bitmask)
      bitmask = Integer(bitmask)
      if (bitmask < 0 || bitmask > 0b11111)
        raise ArgumentError.new("bitmask must be specified as an integer from 0 to #{0b11111.to_s(10)}")
      end

      WEEK_OF_MONTH_CONST_MAP.values.each_with_object([]) do |week, names|
        names << WEEK_OF_MONTH_CONST_MAP.key(week) if bitmask & week != 0
      end
    end
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

    TYPE_MANIFEST_MAP = {
      Type::TASK_TRIGGER_DAILY => 'daily',
      Type::TASK_TRIGGER_WEEKLY => 'weekly',
      # NOTE: monthly uses context to determine MONTHLY or MONTHLYDOW
      Type::TASK_TRIGGER_MONTHLY => 'monthly',
      Type::TASK_TRIGGER_MONTHLYDOW => 'monthly',
      Type::TASK_TRIGGER_TIME => 'once',
    }.freeze

    def self.type_from_manifest_hash(manifest_hash)
      # monthly schedule defaults to TASK_TRIGGER_MONTHLY unless...
      if manifest_hash['schedule'] == 'monthly' &&
        (manifest_hash.key?('which_occurrence') || manifest_hash.key?('day_of_week'))
        return Type::TASK_TRIGGER_MONTHLYDOW
      end

      TYPE_MANIFEST_MAP.key(manifest_hash['schedule'])
    end

    def self.to_manifest_hash(iTrigger)
      if TYPE_MANIFEST_MAP[iTrigger.Type].nil?
        raise ArgumentError.new(_("Unknown trigger type %{type}") % { type: iTrigger.ole_type.to_s })
      end

      trigger_flags = 0
      trigger_flags = trigger_flags | V1::Flag::TASK_TRIGGER_FLAG_HAS_END_DATE unless iTrigger.EndBoundary.empty?
      # There is no corresponding setting for the V1 flag TASK_TRIGGER_FLAG_KILL_AT_DURATION_END
      trigger_flags = trigger_flags | V1::Flag::TASK_TRIGGER_FLAG_DISABLED unless iTrigger.Enabled

      # StartBoundary and EndBoundary may be empty strings per V2 API
      start_boundary = Trigger.iso8601_datetime_to_local(iTrigger.StartBoundary)
      end_boundary = Trigger.iso8601_datetime_to_local(iTrigger.EndBoundary)

      manifest_hash = {
        'start_date'       => start_boundary ? start_boundary.strftime('%Y-%-m-%-d') : '',
        'start_time'       => start_boundary ? start_boundary.strftime('%H:%M') : '',
        'enabled'          => trigger_flags & V1::Flag::TASK_TRIGGER_FLAG_DISABLED == 0,
        'minutes_interval' => Duration.to_minutes(iTrigger.Repetition.Interval) || 0,
        'minutes_duration' => Duration.to_minutes(iTrigger.Repetition.Duration) || 0,
      }

      case iTrigger.Type
        when Type::TASK_TRIGGER_TIME
          manifest_hash['schedule'] = 'once'
        when Type::TASK_TRIGGER_DAILY
          manifest_hash.merge!({
            'schedule' => 'daily',
            'every'    => iTrigger.DaysInterval.to_s,
          })
        when Type::TASK_TRIGGER_WEEKLY
          manifest_hash.merge!({
            'schedule'    => 'weekly',
            'every'       => iTrigger.WeeksInterval.to_s,
            'day_of_week' => V1::Day.bitmask_to_names(iTrigger.DaysOfWeek),
          })
        when Type::TASK_TRIGGER_MONTHLY
          manifest_hash.merge!({
            'schedule' => 'monthly',
            'months'   => V1::Month.bitmask_to_indexes(iTrigger.MonthsOfYear),
            'on'       => V1::Days.bitmask_to_indexes(iTrigger.DaysOfMonth),
          })
        when Type::TASK_TRIGGER_MONTHLYDOW
          occurrences = V2::WeeksOfMonth.bitmask_to_names(iTrigger.WeeksOfMonth)
          manifest_hash.merge!({
            'schedule' => 'monthly',
            'months'           => V1::Month.bitmask_to_indexes(iTrigger.MonthsOfYear),
            # HACK: choose only the first week selected when converting - this LOSES information
            'which_occurrence' => occurrences.first || '',
            'day_of_week'      => V1::Day.bitmask_to_names(iTrigger.DaysOfWeek),
          })
      end

      manifest_hash
    end

    def self.append_trigger(definition, manifest_hash)
      manifest_hash = Trigger::V1.canonicalize_and_validate_manifest(manifest_hash)
      # create appropriate ITrigger based on 'schedule'
      iTrigger = definition.Triggers.Create(type_from_manifest_hash(manifest_hash))

      # Values for all Trigger Types
      if manifest_hash['minutes_interval']
        minutes_interval = manifest_hash['minutes_interval']
        if minutes_interval > 0
          iTrigger.Repetition.Interval = "PT#{minutes_interval}M"
          # one day in minutes
          iTrigger.Repetition.Duration = "PT1440M" unless manifest_hash.key?('minutes_duration')
        end
      end

      if manifest_hash['minutes_duration']
        minutes_duration = manifest_hash['minutes_duration']
        iTrigger.Repetition.Duration = "PT#{minutes_duration}M" unless minutes_duration.zero?
      end

      # manifests specify datetime in the local timezone, ITrigger accepts ISO8601
      # when start_date is null or missing, Time.parse returns today
      datetime_string = "#{manifest_hash['start_date']} #{manifest_hash['start_time']}"
      # Time.parse always assumes local time
      iTrigger.StartBoundary = Time.parse(datetime_string).iso8601

      # ITrigger specific settings
      case iTrigger.Type
        when Type::TASK_TRIGGER_DAILY
          # https://msdn.microsoft.com/en-us/library/windows/desktop/aa446858(v=vs.85).aspx
          iTrigger.DaysInterval = Integer(manifest_hash['every'] || 1)

        when Type::TASK_TRIGGER_WEEKLY
          days_of_week = manifest_hash['day_of_week'] || Trigger::V1::Day.names
          # https://msdn.microsoft.com/en-us/library/windows/desktop/aa384019(v=vs.85).aspx
          iTrigger.DaysOfWeek = Trigger::V1::Day.names_to_bitmask(days_of_week)
          iTrigger.WeeksInterval = Integer(manifest_hash['every'] || 1)

        when Type::TASK_TRIGGER_MONTHLY
          # https://msdn.microsoft.com/en-us/library/windows/desktop/aa382062(v=vs.85).aspx
          iTrigger.DaysOfMonth = Trigger::V1::Days.indexes_to_bitmask(manifest_hash['on'])
          iTrigger.MonthsOfYear = Trigger::V1::Month.indexes_to_bitmask(manifest_hash['months'] || (1..12).to_a)

        when Type::TASK_TRIGGER_MONTHLYDOW
          # https://msdn.microsoft.com/en-us/library/windows/desktop/aa382055(v=vs.85).aspx
          iTrigger.DaysOfWeek = Trigger::V1::Day.names_to_bitmask(manifest_hash['day_of_week'])
          iTrigger.MonthsOfYear = Trigger::V1::Month.indexes_to_bitmask(manifest_hash['months'] || (1..12).to_a)
          # HACK: convert V1 week value to names, then back to V2 bitmask
          iTrigger.WeeksOfMonth = WeeksOfMonth.names_to_bitmask(manifest_hash['which_occurrence'])
      end

      nil
    end
  end
end
end
end
end
