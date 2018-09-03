require 'beaker-pe'
require 'beaker-puppet'
require 'beaker-rspec'
require 'beaker/puppet_install_helper'
require 'beaker/module_install_helper'
require 'beaker/testmode_switcher'
require 'beaker/testmode_switcher/dsl'

run_puppet_install_helper
configure_type_defaults_on(hosts)

install_module_dependencies_on(hosts)

test_name "Installing Puppet Modules" do
  proj_root = File.expand_path(File.join(File.dirname(__FILE__), '..'))
  hosts.each do |host|
    install_dev_puppet_module_on(host, source: proj_root, module_name: 'scheduled_task')
  end
end

def windows_agents
  agents.select { |agent| agent['platform'].include?('windows') }
end

def add_test_user(host)
  username = "test_user_#{rand(999).to_i}"
  password = "password!@#123"

  command_string = "net user /add #{username} #{password}"

  on(host, command_string) do |r|
    raise r.stderr unless r.stderr.empty?
  end

  [username, password]
end

def remove_test_user(host, username)
  command_string = "net user /delete #{username}"

  on(host, command_string) do |r|
    raise r.stderr unless r.stderr.empty?
  end
end
