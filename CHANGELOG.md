# Changelog

## [Unreleased]

## 0.2.2 - 2018-10-10

### Fixed

- Fix type specs (#24, #27 by @ jeroenvisser101)

### Added

- Add `describe_global/1` (based on #18 by @mindreframer)

## 0.2.1 - 2018-07-30

### Added

- Allow tesla `~> 1.0`

## 0.2.0 - 2018-06-08

### Added

- Add `ExForce.OAuth` to support `authorization_code` and `refresh` in addition to `password` grant type. (#2 and #3 by @chulkilee)
- Add create_sobject (#12 by @epinault, #15 by @dustinfarris)

### Changed

- Rename `ExForce.OAuth.Response` to `ExForce.OAuthResponse`
- Use [tesla](https://hex.pm/packages/tesla).
- Take `Tesla.Client` as the first argument instead of taking `ExForce.Config` or function as the last argument.

### Removed

- Remove `ExForce.Auth` GenServer.

## 0.1.0 - 2017-09-13

### Added

- Add basic features

[Unreleased]: https://github.com/chulkilee/ex_force/compare/v0.2.2...HEAD
