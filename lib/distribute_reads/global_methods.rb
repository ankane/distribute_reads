module DistributeReads
  module GlobalMethods
    def distribute_reads(**options)
      raise ArgumentError, "Missing block" unless block_given?

      unknown_keywords = options.keys - [:failover, :lag_failover, :lag_on, :max_lag, :primary]
      raise ArgumentError, "Unknown keywords: #{unknown_keywords.join(", ")}" if unknown_keywords.any?

      options = DistributeReads.default_options.merge(options)

      previous_value = Thread.current[:distribute_reads]
      begin
        Thread.current[:distribute_reads] = {failover: options[:failover], primary: options[:primary]}

        # TODO ensure same connection is used to test lag and execute queries
        max_lag = options[:max_lag]
        if max_lag && !options[:primary]
          Array(options[:lag_on] || [ActiveRecord::Base]).each do |base_model|
            if DistributeReads.lag(connection: base_model.connection) > max_lag
              if options[:lag_failover]
                # TODO possibly per connection
                Thread.current[:distribute_reads][:primary] = true
              else
                raise DistributeReads::TooMuchLag, "Replica lag over #{max_lag} seconds#{options[:lag_on] ? " on #{base_model.name} connection" : ""}"
              end
            end
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
