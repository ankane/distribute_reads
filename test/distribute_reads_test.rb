require_relative "test_helper"

class DistributeReadsTest < Minitest::Test
  def setup
    # reset context
    if DistributeReads.makara3?
      Makara::Cache.store = :memory
      Makara::Context.set_current(Makara::Context.generate)
    else
      Makara::Context.release_all
    end
  end

  def test_default
    assert_primary
    assert_cache_size 0
  end

  def test_by_default
    by_default do
      assert_replica
      insert_value
      assert_primary
      assert_cache_size 1
    end
  end

  def test_distribute_reads
    insert_value
    assert_primary
    distribute_reads do
      assert_replica
      insert_value
      assert_replica
    end
    assert_cache_size 0
  end

  def test_distribute_reads_by_default
    by_default do
      distribute_reads do
        assert_replica
        insert_value
        assert_replica
      end
      assert_primary
      assert_cache_size 1
    end
  end

  def test_distribute_reads_transaction
    distribute_reads do
      ActiveRecord::Base.transaction do
        assert_primary
      end
    end
    assert_cache_size 0
  end

  def test_max_lag
    error = assert_raises DistributeReads::TooMuchLag do
      with_lag(2) do
        distribute_reads(max_lag: 1) do
          run_query
        end
      end
    end
    assert_equal "Replica lag over 1 seconds", error.message
  end

  def test_max_lag_under
    with_lag(0) do
      distribute_reads(max_lag: 1) do
        assert_replica
      end
    end
  end

  def test_lag_nil
    error = assert_raises DistributeReads::TooMuchLag do
      with_lag(nil) do
        distribute_reads(max_lag: 1) do
          run_query
        end
      end
    end
    assert_equal "Replication stopped", error.message
  end

  def test_lag_nil_lag_on
    error = assert_raises DistributeReads::TooMuchLag do
      with_lag(nil) do
        distribute_reads(max_lag: 1, lag_on: User) do
          run_query
        end
      end
    end
    assert_equal "Replication stopped on User connection", error.message
  end

  def test_max_lag_under_not_stubbed
    distribute_reads(max_lag: 1) do
      assert_replica
    end
  end

  def test_lag_failover
    with_lag(2) do
      distribute_reads(max_lag: 1, lag_failover: true) do
        assert_primary
      end
    end
  end

  def test_lag_failover_nil
    with_lag(nil) do
      distribute_reads(max_lag: 1, lag_failover: true) do
        assert_primary
      end
    end
  end

  def test_lag_on
    error = assert_raises DistributeReads::TooMuchLag do
      with_lag(2) do
        distribute_reads(max_lag: 1, lag_on: User) do
          run_query
        end
      end
    end
    assert_equal "Replica lag over 1 seconds on User connection", error.message
  end

  def test_lag_on_array
    error = assert_raises DistributeReads::TooMuchLag do
      with_lag(2) do
        distribute_reads(max_lag: 1, lag_on: [User]) do
          run_query
        end
      end
    end
    assert_equal "Replica lag over 1 seconds on User connection", error.message
  end

  def test_active_job
    TestJob.perform_now
    assert_equal "replica", $current_database
  end

  def test_relation
    assert_log "Call `to_a` inside block to execute query on replica" do
      users =
        distribute_reads do
          User.all
        end
      assert !users.loaded?
    end
  end

  def test_relation_when_loaded
    refute_log "Call `to_a` inside block to execute query on replica" do
      distribute_reads do
        assert_replica
        User.all.load
      end
    end
  end

  def test_eager_load
    with_eager_load do
      refute_log "Call `to_a` inside block to execute query on replica" do
        users =
          distribute_reads do
            assert_replica
            User.all
          end
        assert users.loaded?
      end
    end
  end

  def test_failover_true
    with_replicas_blacklisted do
      distribute_reads do
        assert_primary
      end
    end
  end

  def test_failover_false
    with_replicas_blacklisted do
      assert_raises DistributeReads::NoReplicasAvailable do
        distribute_reads(failover: false) do
          run_query
        end
      end
    end
  end

  def test_by_default_failover_true
    by_default do
      with_replicas_blacklisted do
        distribute_reads do
          assert_primary
        end
      end
    end
  end

  def test_by_default_failover_false
    by_default do
      with_replicas_blacklisted do
        assert_raises DistributeReads::NoReplicasAvailable do
          distribute_reads(failover: false) do
            run_query
          end
        end
      end
    end
  end

  def test_by_default_active_job
    by_default do
      ReadWriteJob.perform_now
      assert_equal "replica", $current_database

      ReadWriteJob.perform_now
      assert_equal "replica", $current_database
    end
  end

  def test_default_options_max_lag
    with_default_options(max_lag: 1) do
      assert_raises DistributeReads::TooMuchLag do
        with_lag(2) do
          distribute_reads do
            run_query
          end
        end
      end
    end
  end

  def test_distribute_reads_by_default_primary
    by_default do
      distribute_reads(primary: true) do
        assert_primary
      end
    end
  end

  def test_missing_block
    error = assert_raises(ArgumentError) { distribute_reads }
    assert_equal "Missing block", error.message
  end

  def test_unknown_keywords
    error = assert_raises(ArgumentError) { distribute_reads(hi: 1, bye: 2) {} }
    assert_equal "Unknown keywords: hi, bye", error.message
  end

  def test_replication_lag
    with_lag(2) do
      assert_equal 2, DistributeReads.replication_lag
    end
  end

  def test_replica
    assert_primary prefix: "/*hi*/"
    distribute_reads(replica: true) do
      assert_replica prefix: "/*hi*/"
    end
  end

  def test_replica_failover_true
    with_replicas_blacklisted do
      distribute_reads(replica: true) do
        assert_primary
      end
    end
  end

  def test_replica_failover_false
    with_replicas_blacklisted do
      assert_raises DistributeReads::NoReplicasAvailable do
        distribute_reads(replica: true, failover: false) do
          run_query
        end
      end
    end
  end

  def test_lag_all_blacklisted
    with_replicas_blacklisted do
      assert_raises DistributeReads::NoReplicasAvailable do
        DistributeReads.replication_lag
      end
    end
  end

  def test_max_lag_no_lag_failover_all_blacklisted
    with_replicas_blacklisted do
      assert_raises DistributeReads::TooMuchLag do
        distribute_reads(max_lag: 1, lag_failover: false) do
          # raises error on lag check
        end
      end
    end
  end

  # lag failover overrides failover
  # unsure if this is best behavior, but it's current behavior
  def test_max_lag_no_failover_all_blacklisted
    with_replicas_blacklisted do
      distribute_reads(max_lag: 1, failover: false, lag_failover: true) do
        assert_primary
      end
    end
  end

  # TODO uncomment in 0.4.0
  # def test_nil
  #   assert !nil.respond_to?(:distribute_reads)
  # end

  private

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

  def with_replicas_blacklisted
    ActiveRecord::Base.connection.instance_variable_get(:@slave_pool).stub(:completely_blacklisted?, true) do
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
    previous_logger = DistributeReads.logger
    begin
      DistributeReads.logger = Logger.new(io)
      yield
    ensure
      DistributeReads.logger = previous_logger
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
    if DistributeReads.makara3?
      assert_equal value, Makara::Cache.send(:store).instance_variable_get(:@data).size
    else
      assert_equal value, Makara::Context.send(:current).staged_data.size
    end
  end
end
