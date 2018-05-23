require 'spec_helper_acceptance'

host = find_only_one("default")

describe "Should create a scheduled task", :node => host do

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

  it "Should create a task if it does not exist", :tier_high => true do
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

  it "Should create a task if it does not exist", :tier_high => true do
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
end
