require 'spec_helper_acceptance'

host = find_only_one("default")

describe "Should destroy a scheduled task", :node => host do

  before(:all) do
    @taskname = "pl#{rand(999999).to_i}"

    pp = <<-MANIFEST
    scheduled_task {'#{@taskname}':
      ensure      => present,
      command     => 'c:\\\\windows\\\\system32\\\\notepad.exe',
      arguments   => "foo bar baz",
      working_dir => 'c:\\\\windows',
      trigger     => {
        schedule   => daily,
        start_time => '12:00',
      },
      provider => 'taskscheduler_api2'
    }
    MANIFEST
    execute_manifest(pp, :catch_failures => true)
  end

  it 'Should destroy the task' do
    # Verify the task exists
    query_cmd = "schtasks.exe /query /v /fo list /tn #{@taskname}"
    on(host, query_cmd)

    pp = <<-MANIFEST
    scheduled_task {'#{@taskname}':
      ensure      => absent,
      provider    => 'taskscheduler_api2'
    }
    MANIFEST

    execute_manifest(pp, :catch_failures => true)

    query_cmd = "schtasks.exe /query /v /fo list /tn #{@taskname}"
    query_out = on(host, query_cmd, :accept_all_exit_codes => true).output
    expect(query_out).to match(/ERROR: The system cannot find the .+ specified/)
  end
end
