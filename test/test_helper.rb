require "bundler/setup"
Bundler.require(:default)
require "minitest/autorun"
require "minitest/pride"

def adapter
  ENV["ADAPTER"] || "postgresql"
end

require_relative "support/active_record"
require_relative "support/active_job"

def insert_value
  User.create!(name: "Boom")
end

def current_database(prefix: nil)
  func = ["mysql2", "trilogy"].include?(adapter) ? "database" : "current_database"
  ActiveRecord::Base.connection.select_all("#{prefix}SELECT #{func}()").rows.first.first.split("_").last
end

class Minitest::Test
  def setup
    # reset context
    ActiveRecord::Base.connection.send(:proxy).send(:current_context=, nil)
  end

  def by_default
    DistributeReads.stub(:by_default, true) do
      yield
    end
  end

  def with_default_options(options)
    DistributeReads.stub(:default_options, options) do
      yield
    end
  end

  def with_eager_load
    DistributeReads.stub(:eager_load, true) do
      yield
    end
  end

  def with_replicas_down
    ActiveRecord::Base.connection.send(:proxy).send(:replica_pool).stub(:checkout, ->(_) { raise ActiveRecord::ConnectionNotEstablished }) do
      yield
    end
  end

  def with_lag(lag)
    DistributeReads.stub(:replication_lag, lag) do
      yield
    end
  end

  def prepare_log
    io = StringIO.new
    logger = ActiveSupport::BroadcastLogger.new(ActiveSupport::Logger.new(io), ActiveRecord::Base.logger)
    DistributeReads.stub(:logger, logger) do
      yield
    end
    io.string
  end

  def assert_log(message, &block)
    assert_includes prepare_log(&block), "[distribute_reads] #{message}"
  end

  def refute_log(message, &block)
    refute_includes prepare_log(&block), "[distribute_reads] #{message}"
  end

  def assert_primary(prefix: nil)
    assert_equal "primary", current_database(prefix: prefix)
  end

  def assert_replica(prefix: nil)
    assert_equal "replica", current_database(prefix: prefix)
  end

  def run_query
    current_database
    raise "Use assert_primary or assert_replica instead"
  end

  def assert_cache_size(value)
    assert_equal value, ActiveRecord::Base.connection.send(:proxy).send(:current_context)&.send(:timestamp_registry)&.size.to_i
  end
end
