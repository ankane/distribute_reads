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

## Jobs [master]

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

Don’t default to primary (default Makara behavior)

```ruby
DistributeReads.default_to_primary = false
```

In this mode, you can force primary with:

```ruby
distribute_reads(:never) { ... }
```

## History

View the [changelog](https://github.com/ankane/distribute_reads/blob/master/CHANGELOG.md)

## Contributing

Everyone is encouraged to help improve this project. Here are a few ways you can help:

- [Report bugs](https://github.com/ankane/distribute_reads/issues)
- Fix bugs and [submit pull requests](https://github.com/ankane/distribute_reads/pulls)
- Write, clarify, or fix documentation
- Suggest or add new features
