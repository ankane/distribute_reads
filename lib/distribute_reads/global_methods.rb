module DistributeReads
  module GlobalMethods
    def distribute_reads(max_lag: nil, failover: true)
      raise ArgumentError, "Missing block" unless block_given?

      if max_lag && DistributeReads.lag > max_lag
        raise DistributeReads::TooMuchLag, "Replica lag over #{max_lag} seconds"
      end

      previous_value = Thread.current[:distribute_reads]
      begin
        Thread.current[:distribute_reads] = {failover: failover}
        value = yield
        warn "[distribute_reads] Call `to_a` inside block to execute query on replica" if value.is_a?(ActiveRecord::Relation) && !previous_value
        value
      ensure
        Thread.current[:distribute_reads] = previous_value
      end
    end
  end
end
