scheduled_task { 'Run Notepad':
  ensure      => present,
  command     => 'C:\Windows\System32\notepad.exe',
  description => 'Task to run notepad',
  trigger     => {
    schedule   => daily,
    start_time => '12:00',
  },
  provider    => 'taskscheduler_api2'
}
