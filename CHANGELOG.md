## Unreleased

## 2018-01-12 - Unsupported Release 0.1.0

### Summary

Initial unsupported release of the scheduled_task module.  Adapts the Puppet scheduled_task resource to use the modern Version 2 API.

### Added

- Added V2 provider for the V1 Puppet type ([MODULES-6264](https://tickets.puppetlabs.com/browse/MODULES-6264), [MODULES-6266](https://tickets.puppetlabs.com/browse/MODULES-6266))
- Added `compatibility` flag, allowing users to specify which version of Scheduled Tasks the task should be compatible with ([MODULES-6526](https://tickets.puppetlabs.com/browse/MODULES-6526))

### Changed

- Updated README with examples for the new provider ([MODULES-6264](https://tickets.puppetlabs.com/browse/MODULES-6264))
- Updated acceptance tests for the new provider ([MODULES-6362](https://tickets.puppetlabs.com/browse/MODULES-6362))
