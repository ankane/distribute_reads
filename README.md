# Distribute Reads

Scale database reads to replicas in Rails

**Distribute Reads 1.0 was recently released** - see [how to upgrade](#upgrading)

:tangerine: Battle-tested at [Instacart](https://www.instacart.com/opensource) with [Makara](https://github.com/instacart/makara)

[![Build Status](https://github.com/ankane/distribute_reads/actions/workflows/build.yml/badge.svg)](https://github.com/ankane/distribute_reads/actions)

## Installation

Add this line to your application’s Gemfile:

```ruby
gem "distribute_reads"
```

## How to Use

[ActiveRecordProxyAdapters](https://github.com/Nasdaq/active_record_proxy_adapters) does most of the work. First, update `config/database.yml` to use it:

```yml
default: &default
  primary:
    adapter: postgresql_proxy
    url: <%= ENV["DATABASE_URL"] %>
  replica:
    adapter: postgresql
    url: <%= ENV["REPLICA_DATABASE_URL"] %>
    replica: true

development:
  <<: *default

production:
  <<: *default
```

**Note:** You can use the same instance for the primary and replica in development.

Then add `connects_to` to `app/models/application_record.rb`:

```ruby
class ApplicationRecord < ActiveRecord::Base
  connects_to database: {writing: :primary, reading: :replica}
end
```

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

You can pass any options as well.

## Lazy Evaluation

Active Record uses [lazy evaluation](https://www.theodinproject.com/lessons/ruby-on-rails-active-record-queries), which can delay the execution of a query to outside of a `distribute_reads` block. In this case, the primary will be used.

```ruby
users = distribute_reads { User.where(orders_count: 1) } # not executed yet
```

Call `to_a` or `load` inside the block to ensure the query runs on a replica.

```ruby
users = distribute_reads { User.where(orders_count: 1).to_a }
```

You can automatically load relations returned from `distribute_reads` blocks by creating an initializer with:

```ruby
DistributeReads.eager_load = true
```

## Options

### Replica Lag

Raise an error when replica lag is too high (specified in seconds)

```ruby
distribute_reads(max_lag: 3) do
  # raises DistributeReads::TooMuchLag
end
```

Instead of raising an error, you can also use primary

```ruby
distribute_reads(max_lag: 3, lag_failover: true) do
  # ...
end
```

If you have multiple databases, this only checks lag on `ActiveRecord::Base` connection. Specify connections to check with

```ruby
distribute_reads(max_lag: 3, lag_on: [ApplicationRecord, LogRecord]) do
  # ...
end
```

**Note:** If lag on any connection exceeds the max lag and lag failover is used, *all connections* will use their primary.

### Availability

If no replicas are available, primary is used. To prevent this situation from overloading the primary, you can raise an error instead.

```ruby
distribute_reads(failover: false) do
  # ...
end
```

### Default Options

Change the defaults for `distribute_reads` blocks

```ruby
DistributeReads.default_options = {
  lag_failover: true,
  failover: false
}
```

### Logging

Messages about failover are logged to the Active Record logger by default. Set a different logger with:

```ruby
DistributeReads.logger = Logger.new(STDERR)
```

Or use `nil` to disable logging.

## Distribute Reads by Default

At some point, you may wish to distribute reads by default.

```ruby
DistributeReads.by_default = true
```

To make queries go to primary, use:

```ruby
distribute_reads(primary: true) do
  # ...
end
```

## Reference

Get replication lag in seconds

```ruby
DistributeReads.replication_lag
```

Most of the time, ActiveRecordProxyAdapters does a great job automatically routing queries to replicas. If it incorrectly routes a query to primary, you can use:

```ruby
distribute_reads(replica: true) do
  # send all queries in block to replica
end
```

## Rails

Rails 6+ has [native support for replicas](https://guides.rubyonrails.org/active_record_multiple_databases.html) :tada:

```ruby
ActiveRecord::Base.connected_to(role: :reading) do
  # do reads
end
```

However, it’s not able to do automatic statement-based routing yet.

## Thanks

Thanks to [Nasdaq](https://github.com/Nasdaq) for ActiveRecordProxyAdapters, [TaskRabbit](https://github.com/taskrabbit) for Makara, [Sherin Kurian](https://github.com/sherin) for the max lag option, and [Nick Elser](https://github.com/nickelser) for the write-through cache.

## Upgrading

### 1.0

ActiveRecordProxyAdapters is now used instead of Makara. Update `config/database.yml` and `app/models/application_record.rb` to [use it](#how-to-use).

## History

View the [changelog](https://github.com/ankane/distribute_reads/blob/master/CHANGELOG.md)

## Contributing

Everyone is encouraged to help improve this project. Here are a few ways you can help:

- [Report bugs](https://github.com/ankane/distribute_reads/issues)
- Fix bugs and [submit pull requests](https://github.com/ankane/distribute_reads/pulls)
- Write, clarify, or fix documentation
- Suggest or add new features

To get started with development and testing:

```sh
git clone https://github.com/ankane/distribute_reads.git
cd distribute_reads
createdb distribute_reads_test_primary
createdb distribute_reads_test_replica
bundle install
bundle exec rake test
```
