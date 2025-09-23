require_relative "test_helper"

class DistributeReadsTest < Minitest::Test
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
    assert_log "No replicas available. Falling back to primary." do
      with_replicas_down do
        distribute_reads do
          assert_primary
        end
      end
    end
  end

  def test_failover_false
    with_replicas_down do
      assert_raises ActiveRecord::ConnectionNotEstablished do
        distribute_reads(failover: false) do
          run_query
        end
      end
    end
  end

  def test_by_default_failover_true
    assert_log "No replicas available. Falling back to primary." do
      by_default do
        with_replicas_down do
          distribute_reads do
            assert_primary
          end
        end
      end
    end
  end

  def test_by_default_failover_false
    by_default do
      with_replicas_down do
        assert_raises ActiveRecord::ConnectionNotEstablished do
          distribute_reads(failover: false) do
            run_query
          end
        end
      end
    end
  end

  def test_by_default_failover_no_block
    by_default do
      with_replicas_down do
        assert_primary
      end
    end
  end

  # unsure if this is best behavior, but it's current behavior
  def test_by_default_failover_no_block_default_options
    with_default_options(failover: false) do
      by_default do
        with_replicas_down do
          assert_primary
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
    error = assert_raises(ArgumentError) { distribute_reads(hi: 1, bye: 2) { } }
    assert_equal "Unknown keywords: hi, bye", error.message
  end

  def test_replica
    assert_primary prefix: "/*hi*/"
    distribute_reads(replica: true) do
      assert_replica prefix: "/*hi*/"
    end
  end

  def test_replica_failover_true
    assert_log "No replicas available. Falling back to primary." do
      with_replicas_down do
        distribute_reads(replica: true) do
          assert_primary
        end
      end
    end
  end

  def test_replica_failover_false
    with_replicas_down do
      assert_raises ActiveRecord::ConnectionNotEstablished do
        distribute_reads(replica: true, failover: false) do
          run_query
        end
      end
    end
  end

  def test_nil
    assert !nil.respond_to?(:distribute_reads)
  end
end
