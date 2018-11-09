module DistributeReads
  module AppropriatePool
    def _appropriate_pool(*args)
      if Thread.current[:distribute_reads]
        if Thread.current[:distribute_reads][:replica]
          if @slave_pool.completely_blacklisted?
            raise DistributeReads::NoReplicasAvailable, "No replicas available" if Thread.current[:distribute_reads][:failover] == false
            warn "No replicas available. Falling back to master pool."
            @master_pool
          else
            @slave_pool
          end
        elsif Thread.current[:distribute_reads][:primary] || needs_master?(*args) || (blacklisted = @slave_pool.completely_blacklisted?)
          raise DistributeReads::NoReplicasAvailable, "No replicas available" if blacklisted && Thread.current[:distribute_reads][:failover] == false
          warn "No replicas available. Falling back to master pool." if blacklisted
          stick_to_master(*args) if DistributeReads.by_default
          @master_pool
        elsif in_transaction?
          @master_pool
        else
          @slave_pool
        end
      elsif !DistributeReads.by_default
        @master_pool
      else
        super
      end
    end
  end
end
