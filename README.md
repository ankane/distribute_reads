# Distribute Reads

Scale database reads to replicas in Rails

:tangerine: Battle-tested at [Instacart](https://www.instacart.com/opensource)

[![Build Status](https://travis-ci.org/ankane/distribute_reads.svg?branch=master)](https://travis-ci.org/ankane/distribute_reads)

## Installation

Add this line to your application’s Gemfile:

```ruby
gem 'distribute_reads'
```

## How to Use

[Makara](https://github.com/taskrabbit/makara) does most of the work. First, update `database.yml` to use it:

```yml
default: &default
  url: postgresql-makara:///
  makara:
    sticky: true
    connections:
      - role: master
        name: primary
        url: <%= ENV["DATABASE_URL"] %>
      - name: replica
        url: <%= ENV["REPLICA_DATABASE_URL"] %>

development:
  <<: *default

production:
  <<: *default
```

**Note:** You can use the same instance for the primary and replica in development.

By default, all reads go to the primary instance. To use the replica, do:

```ruby
distribute_reads { User.count }
```

Works with multiple queries as well.

```ruby
distribute_reads do
  User.find_each do |user|                 # replica
    user.orders_count = user.orders.count  # replica
    user.save!                             # primary
  end
end
```

## Jobs

Distribute all reads in a job with:

```ruby
class TestJob < ApplicationJob
  distribute_reads

  def perform
    # ...
  end
end
```

## Options

Raise an error when replica lag is too high - *PostgreSQL only*

```ruby
distribute_reads(max_lag: 3) do
  # raises DistributeReads::TooMuchLag
end
```

If you have multiple databases, this only checks lag on `ActiveRecord::Base` connection. Specify connections to check with [master]

```ruby
distribute_reads(max_lag: 3, lag_on: [ApplicationRecord, LogRecord]) do
  # ...
end
```

Use primary when replica lag is too high [master]

```ruby
distribute_reads(max_lag: 3, lag_failover: true) do
  # ...
end
```

Raise an error when no replicas available (instead of using primary) [master]

```ruby
distribute_reads(failover: false) do
  # raises DistributeReads::NoReplicasAvailable
end
```

Change the defaults [master]

```ruby
DistributeReads.default_options = {
  lag_failover: true,
  failover: false
}
```

## Distribute Reads by Default

At some point, you may wish to distribute reads by default.

```ruby
DistributeReads.by_default = true
```

Once you do this, Makara will use the Rails cache to track its state. To reduce load on the Rails cache, use a write-through cache in front of it. [master]

```ruby
Makara::Cache.store = DistributeReads::CacheStore.new
```

## Thanks

Thanks to [TaskRabbit](https://github.com/taskrabbit) for Makara and [Nick Elser](https://github.com/nickelser) for the write-through cache.

## History

View the [changelog](https://github.com/ankane/distribute_reads/blob/master/CHANGELOG.md)

## Contributing

Everyone is encouraged to help improve this project. Here are a few ways you can help:

- [Report bugs](https://github.com/ankane/distribute_reads/issues)
- Fix bugs and [submit pull requests](https://github.com/ankane/distribute_reads/pulls)
- Write, clarify, or fix documentation
- Suggest or add new features
