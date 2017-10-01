module DistributeReads
  module GlobalMethods
    def distribute_reads(max_lag: nil, failover: true, lag_failover: false)
      raise ArgumentError, "Missing block" unless block_given?

      previous_value = Thread.current[:distribute_reads]
      begin
        Thread.current[:distribute_reads] = {failover: failover}

        # TODO ensure same connection is used to test lag and execute queries
        if max_lag && DistributeReads.lag > max_lag
          if lag_failover
            Thread.current[:distribute_reads] = {primary: true}
          else
            raise DistributeReads::TooMuchLag, "Replica lag over #{max_lag} seconds"
          end
        end

        value = yield
        warn "[distribute_reads] Call `to_a` inside block to execute query on replica" if value.is_a?(ActiveRecord::Relation) && !previous_value
        value
      ensure
        Thread.current[:distribute_reads] = previous_value
      end
    end
  end
end
