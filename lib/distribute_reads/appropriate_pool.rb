module DistributeReads
  module AppropriatePool
    def _appropriate_pool(*args)
      if Thread.current[:distribute_reads]
        if needs_master?(*args) || (blacklisted = @slave_pool.completely_blacklisted?)
          raise DistributeReads::NoReplicasAvailable, "No replicas available" if blacklisted && Thread.current[:distribute_reads][:failover] == false
          stick_to_master(*args) unless DistributeReads.default_to_primary
          @master_pool
        elsif in_transaction?
          @master_pool
        else
          @slave_pool
        end
      elsif DistributeReads.default_to_primary
        @master_pool
      else
        super
      end
    end
  end
end
