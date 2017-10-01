require_relative "test_helper"

class DistributeReadsTest < Minitest::Test
  def setup
    # reset context
    Makara::Cache.store = :memory
    Makara::Context.set_current(Makara::Context.generate)
  end

  def test_default
    assert_primary
    assert_cache_size 0
  end

  def test_default_to_primary
    DistributeReads.default_to_primary = false
    assert_replica
    insert_value
    assert_primary
    assert_cache_size 1
  ensure
    DistributeReads.default_to_primary = true
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

  def test_distribute_reads_default_to_primary_false
    DistributeReads.default_to_primary = false
    distribute_reads do
      assert_replica
      insert_value
      assert_replica
    end
    assert_primary
    assert_cache_size 1
  ensure
    DistributeReads.default_to_primary = true
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
    DistributeReads.stub(:lag, 2) do
      assert_raises DistributeReads::TooMuchLag do
        distribute_reads(max_lag: 1) do
          assert_replica
        end
      end
    end
  end

  def test_max_lag_under
    distribute_reads(max_lag: 1) do
      assert_replica
    end
  end

  def test_active_job
    TestJob.perform_now
    assert_equal "replica", $current_database
  end

  def test_missing_block
    error = assert_raises(ArgumentError) { distribute_reads }
    assert_equal "Missing block", error.message
  end

  def test_relation
    assert_output(nil, /\A\[distribute_reads\]/) do
      distribute_reads do
        User.all
      end
    end
  end

  def test_failover_true
    ActiveRecord::Base.connection.instance_variable_get(:@slave_pool).stub(:completely_blacklisted?, true) do
      distribute_reads do
        assert_primary
      end
    end
  end

  def test_failover_false
    ActiveRecord::Base.connection.instance_variable_get(:@slave_pool).stub(:completely_blacklisted?, true) do
      assert_raises DistributeReads::NoReplicasAvailable do
        distribute_reads(failover: false) do
          assert_replica
        end
      end
    end
  end

  def test_default_to_primary_false_active_job
    DistributeReads.default_to_primary = false

    ReadWriteJob.perform_now
    assert_equal "replica", $current_database

    ReadWriteJob.perform_now
    assert_equal "replica", $current_database
  ensure
    DistributeReads.default_to_primary = true
  end

  private

  def assert_primary
    assert_equal "primary", current_database
  end

  def assert_replica
    assert_equal "replica", current_database
  end

  def assert_cache_size(value)
    assert_equal value, Makara::Cache.send(:store).instance_variable_get(:@data).size
  end
end
