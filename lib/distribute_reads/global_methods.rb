module DistributeReads
  module GlobalMethods
    def distribute_reads(**options)
      raise ArgumentError, "Missing block" unless block_given?

      unknown_keywords = options.keys - [:max_lag, :failover, :lag_failover]
      raise ArgumentError, "Unknown keywords: #{unknown_keywords.join(", ")}" if unknown_keywords.any?

      options = DistributeReads.default_options.merge(options)

      previous_value = Thread.current[:distribute_reads]
      begin
        Thread.current[:distribute_reads] = {failover: options[:failover]}

        # TODO ensure same connection is used to test lag and execute queries
        max_lag = options[:max_lag]
        if max_lag && DistributeReads.lag > max_lag
          if options[:lag_failover]
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
