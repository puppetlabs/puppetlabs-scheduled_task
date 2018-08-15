require 'spec_helper_acceptance'

host = find_only_one("default")

describe "Should create a scheduled task", :node => host do

  before(:all) do
    @username, @password = add_test_user(host)
    @username2, @password2 = add_test_user(host)
  end

  after(:all) do
    remove_test_user(host, @username)
    remove_test_user(host, @username2)
  end

  before(:each) do
    @taskname = "pl#{rand(999999).to_i}"
  end

  after(:each) do
    on(host, "schtasks.exe /delete /tn #{@taskname} /f", :accept_all_exit_codes => true) do |r|
      # Empty means deletion was ok.  The 'The system cannot find the file specified' error occurs
      # if the task does not exist
      unless r.stderr.empty? || r.stderr =~ /ERROR: The system cannot find the .+ specified/
        raise r.stderr
      end
    end
  end

  it "Should create a task if it does not exist: taskscheduler_api2", :tier_high => true do
    pp = <<-MANIFEST
    scheduled_task {'#{@taskname}':
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
    execute_manifest(pp, :catch_failures => true)

    # Ensure it's idempotent
    execute_manifest(pp, :catch_changes  => true)

    # Verify the task exists
    query_cmd = "schtasks.exe /query /v /fo list /tn #{@taskname}"
    on(host, query_cmd)
  end

  it "Should create a task if it does not exist: win32_taskscheduler", :tier_high => true do
    pp = <<-MANIFEST
    scheduled_task {'#{@taskname}':
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
    execute_manifest(pp, :catch_failures => true)

    # Ensure it's idempotent
    execute_manifest(pp, :catch_changes  => true)

    # Verify the task exists
    query_cmd = "schtasks.exe /query /v /fo list /tn #{@taskname}"
    on(host, query_cmd)
  end

  it "Should create a task with a username and password: taskscheduler_api2" do
    pp = <<-MANIFEST
    scheduled_task {'#{@taskname}':
      ensure        => present,
      command       => 'c:\\\\windows\\\\system32\\\\notepad.exe',
      arguments     => "foo bar baz",
      working_dir   => 'c:\\\\windows',
      user          => '#{@username}',
      password      => '#{@password}',
      trigger       => {
        schedule   => daily,
        start_time => '12:00',
      },
    }
    MANIFEST
    execute_manifest(pp, :catch_failures => true)

    # Verify the task exists
    query_cmd = "schtasks.exe /query /v /fo list /tn #{@taskname}"
    on(host, query_cmd) do | result |
      assert_match(@username, result.stdout)
    end
  end

  it "Should create a task with a username and password: win32_taskscheduler" do
    pp = <<-MANIFEST
    scheduled_task {'#{@taskname}':
      ensure        => present,
      command       => 'c:\\\\windows\\\\system32\\\\notepad.exe',
      arguments     => "foo bar baz",
      working_dir   => 'c:\\\\windows',
      user          => '#{@username}',
      password      => '#{@password}',
      trigger       => {
        schedule   => daily,
        start_time => '12:00',
      },
      provider      => 'win32_taskscheduler'
    }
    MANIFEST
    execute_manifest(pp, :catch_failures => true)

    # Verify the task exists
    query_cmd = "schtasks.exe /query /v /fo list /tn #{@taskname}"
    on(host, query_cmd) do | result |
      assert_match(@username, result.stdout)
    end
  end

  it "Should update a task's credentials: win32_taskscheduler" do
    pp = <<-MANIFEST
    scheduled_task {'#{@taskname}':
      ensure        => present,
      command       => 'c:\\\\windows\\\\system32\\\\notepad.exe',
      arguments     => "foo bar baz",
      working_dir   => 'c:\\\\windows',
      user          => '#{@username}',
      password      => '#{@password}',
      trigger       => {
        schedule   => daily,
        start_time => '12:00',
      },
      provider      => 'win32_taskscheduler'
    }
    MANIFEST
    execute_manifest(pp, :catch_failures => true)

    # Verify the task exists
    query_cmd = "schtasks.exe /query /v /fo list /tn #{@taskname}"
    result = on(host, query_cmd)

    on(host, query_cmd) do | result |
      assert_match(@username, result.stdout)
    end

    pp = <<-MANIFEST
    scheduled_task {'#{@taskname}':
      ensure        => present,
      compatibility => 1,
      command       => 'c:\\\\windows\\\\system32\\\\notepad.exe',
      arguments     => "foo bar baz",
      working_dir   => 'c:\\\\windows',
      user          => '#{@username2}',
      password      => '#{@password2}',
      trigger       => {
        schedule   => daily,
        start_time => '12:00',
      },
      provider      => 'win32_taskscheduler'
    }
    MANIFEST
    execute_manifest(pp, :catch_failures => true)

    # Verify the task exists
    query_cmd = "schtasks.exe /query /v /fo list /tn #{@taskname}"

    on(host, query_cmd) do | result |
      assert_match(@username2, result.stdout)
    end
  end

  it "Should update a task's credentials: taskscheduler_api2" do
    pp = <<-MANIFEST
    scheduled_task {'#{@taskname}':
      ensure        => present,
      command       => 'c:\\\\windows\\\\system32\\\\notepad.exe',
      arguments     => "foo bar baz",
      working_dir   => 'c:\\\\windows',
      user          => '#{@username}',
      password      => '#{@password}',
      trigger       => {
        schedule   => daily,
        start_time => '12:00',
      },
    }
    MANIFEST
    execute_manifest(pp, :catch_failures => true)

    # Verify the task exists
    query_cmd = "schtasks.exe /query /v /fo list /tn #{@taskname}"

    on(host, query_cmd) do | result |
      assert_match(@username, result.stdout)
    end

    pp = <<-MANIFEST
    scheduled_task {'#{@taskname}':
      ensure        => present,
      command       => 'c:\\\\windows\\\\system32\\\\notepad.exe',
      arguments     => "foo bar baz",
      working_dir   => 'c:\\\\windows',
      user          => '#{@username2}',
      password      => '#{@password2}',
      trigger       => {
        schedule   => daily,
        start_time => '12:00',
      },
    }
    MANIFEST
    execute_manifest(pp, :catch_failures => true)

    # Verify the task exists
    query_cmd = "schtasks.exe /query /v /fo list /tn #{@taskname}"

    on(host, query_cmd) do | result |
      assert_match(@username2, result.stdout)
    end
  end
end
