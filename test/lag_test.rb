require_relative "test_helper"

class LagTest < Minitest::Test
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
    assert_log "Replica lag over 1 seconds. Falling back to primary." do
      with_lag(2) do
        distribute_reads(max_lag: 1, lag_failover: true) do
          assert_primary
        end
      end
    end
  end

  def test_lag_failover_nil
    assert_log "Replication stopped. Falling back to primary." do
      with_lag(nil) do
        distribute_reads(max_lag: 1, lag_failover: true) do
          assert_primary
        end
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

  def test_max_lag_no_lag_failover_all_down
    with_replicas_down do
      assert_raises DistributeReads::TooMuchLag do
        distribute_reads(max_lag: 1, lag_failover: false) do
          # raises error on lag check
        end
      end
    end
  end

  # lag failover overrides failover
  # unsure if this is best behavior, but it's current behavior
  def test_max_lag_no_failover_all_down
    assert_log "No replicas available for lag check. Falling back to primary." do
      with_replicas_down do
        distribute_reads(max_lag: 1, failover: false, lag_failover: true) do
          assert_primary
        end
      end
    end
  end

  def test_replication_lag
    with_lag(2) do
      assert_equal 2, DistributeReads.replication_lag
    end
  end

  def test_replication_lag_all_down
    with_replicas_down do
      assert_raises ActiveRecord::ConnectionNotEstablished do
        DistributeReads.replication_lag
      end
    end
  end
end
