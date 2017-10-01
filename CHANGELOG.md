## 0.2.0 [unreleased]

Breaking

- Jobs default to replica when `default_to_primary` is false

Other

- Fixed `max_lag` option
- Added `lag_failover` option
- Added `failover` option
- Improved lag query

## 0.1.2

- Raise `ArgumentError` when missing block
- Improved lag query
- Warn if returning `ActiveRecord::Relation`

## 0.1.1

- Added method for jobs

## 0.1.0

- First release
