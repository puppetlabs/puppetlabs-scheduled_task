# frozen_string_literal: true

require 'spec_helper_acceptance'

describe 'Should create a scheduled task' do
  username, password = add_test_user
  username2, password2 = add_test_user
  let(:username) { username }
  let(:username2) { username2 }
  let(:password) { password }
  let(:password2) { password2 }
  let!(:taskname) { "pl#{rand(999_999).to_i}" }
  let(:description) { 'foobar' }

  after(:all) do
    remove_test_user(username)
    remove_test_user(username2)
  end

  after(:each) do
    run_shell("schtasks.exe /delete /tn #{taskname} /f", accept_all_exit_codes: true) do |r|
      # Empty means deletion was ok.  The 'The system cannot find the file specified' error occurs
      # if the task does not exist
      unless r.stderr.empty? || r.stderr =~ %r{ERROR: The system cannot find the .+ specified}
        raise r.stderr
      end
    end
  end

  it 'creates a task that runs on the last day of the month: taskscheduler_api2', tier_high: true do
    pp = <<-MANIFEST
    scheduled_task {'#{taskname}':
      ensure      => present,
      compatibility => 2,
      command     => 'c:\\\\windows\\\\system32\\\\notepad.exe',
      arguments   => "foo bar baz",
      working_dir => 'c:\\\\windows',
      trigger => {
        schedule   => 'monthly',
        start_time => '12:00',
        on         => [1, 3, 'last'],
      },
      provider    => 'taskscheduler_api2'
    }
    MANIFEST
    apply_manifest(pp, catch_failures: true)

    # Verify the task exists
    query_cmd = "schtasks.exe /query /v /fo list /tn #{taskname}"
    run_shell(query_cmd) do |result|
      # Even though the bit mask value for '32' doesn't actuall work to set
      # `last` day of the month as a trigger, schtasks.exe still returns day 32
      # if `last` is set as a trigger day. My guess is that this is for backward
      # compatability with something in schtasks.exe
      expect(result.stdout).to match(%r{Days:.+01, 03, 32})
    end
  end

  it 'creates a task if it does not exist: taskscheduler_api2', tier_high: true do
    pp = <<-MANIFEST
    scheduled_task {'#{taskname}':
      ensure      => present,
      compatibility => 1,
      command     => 'c:\\\\windows\\\\system32\\\\notepad.exe',
      arguments   => "foo bar baz",
      working_dir => 'c:\\\\windows',
      trigger => {
        schedule   => daily,
        start_time => '12:00',
      },
      provider    => 'taskscheduler_api2'
    }
    MANIFEST
    apply_manifest(pp, catch_failures: true)

    # Ensure it's idempotent
    apply_manifest(pp, catch_changes: true)

    # Verify the task exists
    query_cmd = "schtasks.exe /query /v /fo list /tn #{taskname}"
    run_shell(query_cmd)
  end

  it 'creates a task if it does not exist: win32_taskscheduler', tier_high: true do
    pp = <<-MANIFEST
    scheduled_task {'#{taskname}':
      ensure        => present,
      compatibility => 1,
      command       => 'c:\\\\windows\\\\system32\\\\notepad.exe',
      arguments     => "foo bar baz",
      working_dir   => 'c:\\\\windows',
      trigger       => {
        schedule   => daily,
        start_time => '12:00',
      },
      provider      => 'win32_taskscheduler'
    }
    MANIFEST
    apply_manifest(pp, catch_failures: true)

    # Ensure it's idempotent
    apply_manifest(pp, catch_changes: true)

    # Verify the task exists
    query_cmd = "schtasks.exe /query /v /fo list /tn #{taskname}"
    run_shell(query_cmd)
  end

  it 'creates a task with a username and password: taskscheduler_api2' do
    pp = <<-MANIFEST
    scheduled_task {'#{taskname}':
      ensure        => present,
      command       => 'c:\\\\windows\\\\system32\\\\notepad.exe',
      arguments     => "foo bar baz",
      working_dir   => 'c:\\\\windows',
      user          => '#{username}',
      password      => '#{password}',
      trigger       => {
        schedule   => daily,
        start_time => '12:00',
      },
    }
    MANIFEST
    apply_manifest(pp, catch_failures: true)

    # Verify the task exists
    query_cmd = "schtasks.exe /query /v /fo list /tn #{taskname}"
    run_shell(query_cmd) do |result|
      expect(result.stdout).to match(%r{#{username}})
    end
  end

  it 'creates a task with a username and password: win32_taskscheduler' do
    pp = <<-MANIFEST
    scheduled_task {'#{taskname}':
      ensure        => present,
      command       => 'c:\\\\windows\\\\system32\\\\notepad.exe',
      arguments     => "foo bar baz",
      working_dir   => 'c:\\\\windows',
      user          => '#{username}',
      password      => '#{password}',
      trigger       => {
        schedule   => daily,
        start_time => '12:00',
      },
      provider      => 'win32_taskscheduler'
    }
    MANIFEST
    apply_manifest(pp, catch_failures: true)

    # Verify the task exists
    query_cmd = "schtasks.exe /query /v /fo list /tn #{taskname}"
    run_shell(query_cmd) do |result|
      expect(result.stdout).to match(%r{#{username}})
    end
  end

  it 'creates a task with a description: taskscheduler_api2' do
    pp = <<-MANIFEST
    scheduled_task {'#{taskname}':
      ensure        => present,
      command       => 'c:\\\\windows\\\\system32\\\\notepad.exe',
      arguments     => "foo bar baz",
      working_dir   => 'c:\\\\windows',
      description   => '#{description}',
      trigger       => {
        schedule   => daily,
        start_time => '12:00',
      },
    }
    MANIFEST
    apply_manifest(pp, catch_failures: true)

    # Verify the task exists
    query_cmd = "schtasks.exe /query /v /fo list /tn #{taskname}"
    run_shell(query_cmd) do |result|
      expect(result.stdout).to match(%r{#{description}})
    end
  end

  it 'creates a task with a description: win32_taskscheduler' do
    pp = <<-MANIFEST
    scheduled_task {'#{taskname}':
      ensure        => present,
      command       => 'c:\\\\windows\\\\system32\\\\notepad.exe',
      arguments     => "foo bar baz",
      working_dir   => 'c:\\\\windows',
      description   => '#{description}',
      trigger       => {
        schedule   => daily,
        start_time => '12:00',
      },
      provider      => 'win32_taskscheduler'
    }
    MANIFEST
    apply_manifest(pp, catch_failures: true)

    # Verify the task exists
    query_cmd = "schtasks.exe /query /v /fo list /tn #{taskname}"
    run_shell(query_cmd) do |result|
      expect(result.stdout).to match(%r{#{description}})
    end
  end

  it 'creates a task with a username: taskscheduler_api2' do
    pp = <<-MANIFEST
    scheduled_task {'#{taskname}':
      ensure        => present,
      command       => 'c:\\\\windows\\\\system32\\\\notepad.exe',
      arguments     => "foo bar baz",
      working_dir   => 'c:\\\\windows',
      user          => '#{username}',
      trigger       => {
        schedule   => daily,
        start_time => '12:00',
      },
    }
    MANIFEST
    apply_manifest(pp, catch_failures: true)

    # Verify the task exists
    query_cmd = "schtasks.exe /query /v /fo list /tn #{taskname}"
    run_shell(query_cmd) do |result|
      expect(result.stdout).to match(%r{#{username}})
    end
  end

  it 'creates a task with a username: win32_taskscheduler' do
    pp = <<-MANIFEST
    scheduled_task {'#{taskname}':
      ensure        => present,
      command       => 'c:\\\\windows\\\\system32\\\\notepad.exe',
      arguments     => "foo bar baz",
      working_dir   => 'c:\\\\windows',
      user          => '#{username}',
      trigger       => {
        schedule   => daily,
        start_time => '12:00',
      },
      provider      => 'win32_taskscheduler'
    }
    MANIFEST
    apply_manifest(pp, catch_failures: true)

    # Verify the task exists
    query_cmd = "schtasks.exe /query /v /fo list /tn #{taskname}"
    run_shell(query_cmd) do |result|
      expect(result.stdout).to match(%r{#{username}})
    end
  end

  it "updates a task's credentials: win32_taskscheduler" do
    pp = <<-MANIFEST
    scheduled_task {'#{taskname}':
      ensure        => present,
      command       => 'c:\\\\windows\\\\system32\\\\notepad.exe',
      arguments     => "foo bar baz",
      working_dir   => 'c:\\\\windows',
      user          => '#{username}',
      password      => '#{password}',
      trigger       => {
        schedule   => daily,
        start_time => '12:00',
      },
      provider      => 'win32_taskscheduler'
    }
    MANIFEST
    apply_manifest(pp, catch_failures: true)

    # Verify the task exists
    query_cmd = "schtasks.exe /query /v /fo list /tn #{taskname}"
    run_shell(query_cmd) do |result|
      expect(result.stdout).to match(%r{#{username}})
    end

    pp = <<-MANIFEST
    scheduled_task {'#{taskname}':
      ensure        => present,
      compatibility => 1,
      command       => 'c:\\\\windows\\\\system32\\\\notepad.exe',
      arguments     => "foo bar baz",
      working_dir   => 'c:\\\\windows',
      user          => '#{username2}',
      password      => '#{password2}',
      trigger       => {
        schedule   => daily,
        start_time => '12:00',
      },
      provider      => 'win32_taskscheduler'
    }
    MANIFEST
    apply_manifest(pp, catch_failures: true)

    # Verify the task exists
    query_cmd = "schtasks.exe /query /v /fo list /tn #{taskname}"

    run_shell(query_cmd) do |result|
      expect(result.stdout).to match(%r{#{username2}})
    end
  end

  it "updates a task's credentials: taskscheduler_api2" do
    pp = <<-MANIFEST
    scheduled_task {'#{taskname}':
      ensure        => present,
      command       => 'c:\\\\windows\\\\system32\\\\notepad.exe',
      arguments     => "foo bar baz",
      working_dir   => 'c:\\\\windows',
      user          => '#{username}',
      password      => '#{password}',
      trigger       => {
        schedule   => daily,
        start_time => '12:00',
      },
    }
    MANIFEST
    apply_manifest(pp, catch_failures: true)

    # Verify the task exists
    query_cmd = "schtasks.exe /query /v /fo list /tn #{taskname}"

    run_shell(query_cmd) do |result|
      expect(result.stdout).to match(%r{#{username}})
    end

    pp = <<-MANIFEST
    scheduled_task {'#{taskname}':
      ensure        => present,
      command       => 'c:\\\\windows\\\\system32\\\\notepad.exe',
      arguments     => "foo bar baz",
      working_dir   => 'c:\\\\windows',
      user          => '#{username2}',
      password      => '#{password2}',
      trigger       => {
        schedule   => daily,
        start_time => '12:00',
      },
    }
    MANIFEST
    apply_manifest(pp, catch_failures: true)

    # Verify the task exists
    query_cmd = "schtasks.exe /query /v /fo list /tn #{taskname}"

    run_shell(query_cmd) do |result|
      expect(result.stdout).to match(%r{#{username2}})
    end
  end

  it "correctly determines idempotency for tasks with LastWeekOfMonth='last'" do
    pp = <<-MANIFEST
    scheduled_task {'#{taskname}':
      ensure        => present,
      command       => 'c:\\\\windows\\\\system32\\\\notepad.exe',
      arguments     => "foo bar baz",
      working_dir   => 'c:\\\\windows',
      user          => '#{username}',
      password      => '#{password}',
      trigger   => {
        'start_date'       => '2019-9-01',
        'start_time'       => '05:40',
        'minutes_interval' => '0',
        'minutes_duration' => '0',
        'schedule'         => 'monthly',
        'months'           => [1,2,3,4,5,6,7,8,9,10,11,12],
        'which_occurrence' => 'last',
        'day_of_week'      => ['tues']
      },
    }
    MANIFEST
    idempotent_apply(pp)

    # Verify the task exists
    query_cmd = "schtasks.exe /query /v /fo list /tn #{taskname}"

    run_shell(query_cmd) do |result|
      expect(result.stdout).to match(%r{Last\sTUE})
    end
  end

  it 'creates a task with synchronisation disabled: taskscheduler_api2', tier_high: true do
    pp = <<-MANIFEST
    scheduled_task {'#{taskname}':
      ensure      => present,
      compatibility => 1,
      command     => 'c:\\\\windows\\\\system32\\\\notepad.exe',
      arguments   => "foo bar baz",
      working_dir => 'c:\\\\windows',
      trigger => {
        schedule            => daily,
        start_time          => '12:00',
        disable_time_zone_synchronization => true,
      },
      provider    => 'taskscheduler_api2'
    }
    MANIFEST
    apply_manifest(pp, catch_failures: true)

    # Ensure it's idempotent
    apply_manifest(pp, catch_changes: true)

    # Verify the task exists
    query_cmd = "schtasks.exe /query /v /fo list /tn #{taskname}"
    run_shell(query_cmd)
  end

  it 'creates a task with synchronisation disabled: win32_taskscheduler', tier_high: true do
    pp = <<-MANIFEST
    scheduled_task {'#{taskname}':
      ensure        => present,
      compatibility => 1,
      command       => 'c:\\\\windows\\\\system32\\\\notepad.exe',
      arguments     => "foo bar baz",
      working_dir   => 'c:\\\\windows',
      trigger       => {
        schedule            => daily,
        start_time          => '12:00',
        disable_time_zone_synchronization => true,
      },
      provider      => 'win32_taskscheduler'
    }
    MANIFEST
    apply_manifest(pp, catch_failures: true)

    # Ensure it's idempotent
    apply_manifest(pp, catch_changes: true)

    # Verify the task exists
    query_cmd = "schtasks.exe /query /v /fo list /tn #{taskname}"
    run_shell(query_cmd)
  end
end
