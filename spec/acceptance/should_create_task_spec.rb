require 'spec_helper_acceptance'

describe 'Should create a scheduled task' do
  username, password = add_test_user
  username2, password2 = add_test_user
  let(:username) { username }
  let(:username2) { username2 }
  let(:password) { password }
  let(:password2) { password2 }
  let!(:taskname) { "pl#{rand(999_999).to_i}" }

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
end
