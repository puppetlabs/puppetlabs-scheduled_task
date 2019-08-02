require 'spec_helper_acceptance'

describe 'Should destroy a scheduled task', node: host do
  before :each do
    pp = <<-MANIFEST
    scheduled_task {'#{taskname}':
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
    apply_manifest(pp, catch_failures: true)
  end

  context 'with taskname' do
    let(:taskname) { "pl#{rand(999_999).to_i}" }

    it 'destroys the task' do
      # Verify the task exists
      query_cmd = "schtasks.exe /query /v /fo list /tn #{taskname}"
      run_shell(query_cmd)

      pp = <<-MANIFEST
      scheduled_task {'#{taskname}':
        ensure      => absent,
        provider    => 'taskscheduler_api2'
      }
      MANIFEST

      apply_manifest(pp, catch_failures: true)

      query_cmd = "schtasks.exe /query /v /fo list /tn #{taskname}"
      query_out = run_shell(query_cmd, expect_failures: true)
      expect(query_out.to_s).to match(%r{ERROR: The system cannot find the file specified})
    end
  end
end
