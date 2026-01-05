require "bundler/setup"
Bundler.require(:default)
require "minitest/autorun"

def adapter
  ENV["ADAPTER"] || "postgresql"
end

def stub_method(cls, method, code)
  original_code = cls.method(method)
  begin
    cls.singleton_class.undef_method(method)
    cls.define_singleton_method(method, code.respond_to?(:call) ? code : ->(*) { code })
    yield
  ensure
    cls.singleton_class.undef_method(method) if cls.singleton_class.method_defined?(method)
    cls.define_singleton_method(method, original_code)
  end
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
    stub_method(DistributeReads, :by_default, true) do
      yield
    end
  end

  def with_default_options(options)
    stub_method(DistributeReads, :default_options, options) do
      yield
    end
  end

  def with_eager_load
    stub_method(DistributeReads, :eager_load, true) do
      yield
    end
  end

  def with_replicas_down
    stub_method(ActiveRecord::Base.connection.send(:proxy).send(:replica_pool), :checkout, ->(_) { raise ActiveRecord::ConnectionNotEstablished }) do
      yield
    end
  end

  def with_lag(lag)
    stub_method(DistributeReads, :replication_lag, lag) do
      yield
    end
  end

  def prepare_log
    io = StringIO.new
    logger = ActiveSupport::BroadcastLogger.new(ActiveSupport::Logger.new(io), ActiveRecord::Base.logger)
    stub_method(DistributeReads, :logger, logger) do
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
