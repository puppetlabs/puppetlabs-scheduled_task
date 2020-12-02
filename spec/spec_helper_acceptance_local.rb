# frozen_string_literal: true

def add_test_user
  username = "test_user_#{rand(999).to_i}"
  password = 'password!@#123'

  command_string = "net user /add #{username} #{password}"
  run_shell(command_string) do |r|
    raise r.stderr unless r.stderr.empty?
  end
  [username, password]
end

def remove_test_user(username)
  command_string = "net user /delete #{username}"
  run_shell(command_string) do |r|
    raise r.stderr unless r.stderr.empty?
  end
end
