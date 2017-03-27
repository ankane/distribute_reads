module DistributeReads
  module AppropriatePool
    def _appropriate_pool(*args)
      if Thread.current[:distribute_reads]
        if needs_master?(*args) || @slave_pool.completely_blacklisted? || in_transaction?
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
