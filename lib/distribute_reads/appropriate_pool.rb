module DistributeReads
  module AppropriatePool
    def _appropriate_pool(*args)
      if Thread.current[:distribute_reads]
        if Thread.current[:distribute_reads][:replica]
          if @replica_pool.completely_blacklisted?
            raise DistributeReads::NoReplicasAvailable, "No replicas available" if Thread.current[:distribute_reads][:failover] == false
            DistributeReads.log "No replicas available. Falling back to primary pool."
            @primary_pool
          else
            @replica_pool
          end
        elsif Thread.current[:distribute_reads][:primary] || needs_primary?(*args) || (blacklisted = @replica_pool.completely_blacklisted?)
          if blacklisted
            if Thread.current[:distribute_reads][:failover] == false
              raise DistributeReads::NoReplicasAvailable, "No replicas available"
            else
              DistributeReads.log "No replicas available. Falling back to primary pool."
            end
          end
          stick_to_primary(*args) if DistributeReads.by_default
          @primary_pool
        elsif in_transaction?
          @primary_pool
        else
          @replica_pool
        end
      elsif !DistributeReads.by_default
        @primary_pool
      else
        super
      end
    end
  end
end
