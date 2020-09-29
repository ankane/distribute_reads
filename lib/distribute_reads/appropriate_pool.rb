require 'active_record'

module DistributeReads
  module AppropriatePool

    ENABLE_REPORTING = ActiveRecord::Type::Boolean.new.deserialize(ENV.fetch("DISTRIBUTE_READS_ENABLE_REPORTING", "false"))
    private_constant :ENABLE_REPORTING

    def _appropriate_pool(*args)
      if Thread.current[:distribute_reads]
        if Thread.current[:distribute_reads][:replica]
          if @slave_pool.completely_blacklisted?
            raise DistributeReads::NoReplicasAvailable, "No replicas available" if Thread.current[:distribute_reads][:failover] == false
            DistributeReads.log "No replicas available. Falling back to master pool."
            @master_pool
          else
            report_metric("distribute_reads.read", @config[:ic_logical_name], "replica", stuck_to_master? ? true : false)
            @slave_pool
          end
        elsif Thread.current[:distribute_reads][:primary] || needs_master?(*args) || (blacklisted = @slave_pool.completely_blacklisted?)
          if blacklisted
            if Thread.current[:distribute_reads][:failover] == false
              raise DistributeReads::NoReplicasAvailable, "No replicas available"
            else
              DistributeReads.log "No replicas available. Falling back to master pool."
            end
          end
          report_metric("distribute_reads.read", @config[:ic_logical_name], "primary", stuck_to_master? ? true : false) if Thread.current[:distribute_reads][:primary] && !needs_master?(*args)
          stick_to_master(*args) if DistributeReads.by_default
          @master_pool
        elsif in_transaction?
          @master_pool
        else
          report_metric("distribute_reads.read", @config[:ic_logical_name], "replica", stuck_to_master? ? true : false)
          @slave_pool
        end
      elsif !DistributeReads.by_default
        @master_pool
      else
        super
      end
    end

    def report_metric(metric, db_name, pool_requested, makara_primary )
      ICMetrics.increment(metric, { db_name: db_name, pool_requested: pool_requested, makara_primary: makara_primary }) if ENABLE_REPORTING
    end

  end
end
