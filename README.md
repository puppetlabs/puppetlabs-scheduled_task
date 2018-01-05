# scheduled_task

#### Table of Contents

1. [Description](#description)
2. [Setup - The basics of getting started with scheduled_task](#setup)
    * [What scheduled_task affects](#what-scheduled_task-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with scheduled_task](#beginning-with-scheduled_task)
3. [Usage - Configuration options and additional functionality](#usage)
4. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
5. [Limitations - OS compatibility, etc.](#limitations)
6. [Development - Guide for contributing to the module](#development)

## Description

This module adds a new [scheduled_task](https://puppet.com/docs/puppet/latest/types/scheduled_task.html) provider capable of using the more modern Version 2 Windows API for task management.

## Setup

### Beginning with scheduled_task

The scheduled_task module adapts the Puppet [scheduled_task](https://puppet.com/docs/puppet/latest/types/scheduled_task.html) resource to run using a modern API. To get started, install the module and declare 'taskscheduler_api2' as the provider, for example:

~~~ puppet
scheduled_task { 'Run Notepad':
  command  => "notepad.exe",
  ...
  provider => 'taskscheduler_api2'
}
~~~

## Usage

See the [Puppet resource documentation](https://puppet.com/docs/puppet/latest/types/scheduled_task.html) for more information.

## Reference

### Provider

* taskscheduler_api2: Adapts the Puppet scheduled_task resource to use the modern Version 2 API.

### Type

* scheduled_task: See the [Puppet resource documentation](https://puppet.com/docs/puppet/latest/types/scheduled_task.html) for more information.

## Limitations

* Only supported on Windows Server 2008 and above, and Windows 7 and above.

## Development

Puppet modules on the Puppet Forge are open projects, and community contributions are essential for keeping them great. We can’t access the huge number of platforms and myriad hardware, software, and deployment configurations that Puppet is intended to serve, therefore want to keep it as easy as possible to contribute changes so that our modules work in your environment. There are a few guidelines that we need contributors to follow so that we can have a chance of keeping on top of things. For guidelines on how to contribute, see our [module contribution guide.](https://docs.puppet.com/forge/contributing.html)
