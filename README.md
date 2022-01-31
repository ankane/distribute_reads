# Distribute Reads

Scale database reads to replicas in Rails

:tangerine: Battle-tested at [Instacart](https://www.instacart.com/opensource)

[![Build Status](https://github.com/ankane/distribute_reads/workflows/build/badge.svg?branch=master)](https://github.com/ankane/distribute_reads/actions)

## Installation

Add this line to your application’s Gemfile:

```ruby
gem "distribute_reads"
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

You can pass any options as well.

## Lazy Evaluation

ActiveRecord uses [lazy evaluation](https://www.theodinproject.com/courses/ruby-on-rails/lessons/active-record-queries), which can delay the execution of a query to outside of a `distribute_reads` block. In this case, the primary will be used.

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
  # raises DistributeReads::NoReplicasAvailable
end
```

### Default Options

Change the defaults

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

Most of the time, Makara does a great job automatically routing queries to replicas. If it incorrectly routes a query to primary, you can use:

```ruby
distribute_reads(replica: true) do
  # send all queries in block to replica
end
```

## Rails 6

Rails 6 has [native support for replicas](https://guides.rubyonrails.org/active_record_multiple_databases.html) :tada:

```ruby
ActiveRecord::Base.connected_to(role: :reading) do
  # do reads
end
```

However, it’s not able to automatically route queries like Makara just yet.

## Thanks

Thanks to [TaskRabbit](https://github.com/taskrabbit) for Makara, [Sherin Kurian](https://github.com/sherinkurian) for the max lag option, and [Nick Elser](https://github.com/nickelser) for the write-through cache.

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
