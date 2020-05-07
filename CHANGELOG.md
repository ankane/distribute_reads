## 0.3.3 (2020-05-06)

- Fixed deprecation warning with MySQL

## 0.3.2 (2020-01-02)

- Added `eager_load` option
- Removed warning when relation is loaded

## 0.3.1 (2019-10-28)

- Added source location to logging

## 0.3.0 (2019-06-14)

- Use logger instead of stderr
- Handle `NULL` replication lag for MySQL
- Fixed replication lag check running on primary when replicas blacklisted

## 0.2.4 (2018-11-14)

- Added support for Aurora MySQL replication lag
- Added more logging

## 0.2.3 (2018-05-24)

- Added support for Makara 0.4

## 0.2.2 (2018-03-29)

- Added support for MySQL replication lag
- Added `replica` option

## 0.2.1 (2017-12-14)

- Fixed lag check for Postgres 10
- Added `replication_lag` method

## 0.2.0 (2017-10-02)

Breaking

- Jobs default to replica when `default_to_primary` is false

Other

- Replaced `default_to_primary` with `by_default`
- Fixed `max_lag` option
- Added `lag_failover` option
- Added `failover` option
- Added `lag_on` option
- Added `primary` option
- Added default options
- Improved lag query

## 0.1.2 (2017-09-20)

- Raise `ArgumentError` when missing block
- Improved lag query
- Warn if returning `ActiveRecord::Relation`

## 0.1.1 (2017-05-14)

- Added method for jobs

## 0.1.0 (2017-03-26)

- First release
