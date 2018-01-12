require 'beaker-rspec'
require 'beaker/puppet_install_helper'
require 'beaker/module_install_helper'
require 'beaker/testmode_switcher'
require 'beaker/testmode_switcher/dsl'

run_puppet_install_helper

install_module_dependencies_on(hosts)

test_name "Installing Puppet Modules" do
  proj_root = File.expand_path(File.join(File.dirname(__FILE__), '..'))
  hosts.each do |host|
    if host['platform'] =~ /windows/
      on host, "mkdir -p #{host['distmoduledir']}/scheduled_task"
      target = (on host, "echo #{host['distmoduledir']}/scheduled_task").raw_output.chomp

      %w(lib metadata.json).each do |file|
        scp_to host, "#{proj_root}/#{file}", target
      end
    end
  end
end

def windows_agents
  agents.select { |agent| agent['platform'].include?('windows') }
end
