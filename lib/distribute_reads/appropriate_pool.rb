module DistributeReads
  module AppropriatePool
    def _appropriate_pool(*args)
      if Thread.current[:distribute_reads]
        @slave_pool.current_name = Thread.current[:distribute_reads][:name]

        if Thread.current[:distribute_reads][:replica]
          if @slave_pool.completely_blacklisted?
            raise DistributeReads::NoReplicasAvailable, "No replicas available" if Thread.current[:distribute_reads][:failover] == false
            DistributeReads.log "No replicas available. Falling back to master pool."
            @master_pool
          else
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

    # Allows you to define a new Makara strategy (NameSelect) to select the replica
    # specified by the :name option in database.yml.
    def strategy_class_for(strategy_name)
      case strategy_name
      when 'round_robin', 'roundrobin', nil, ''
        ::Makara::Strategies::RoundRobin
      when 'failover'
        ::Makara::Strategies::PriorityFailover
      when 'name_select'
        ::Makara::Strategies::NameSelect
      else
        strategy_name.constantize
      end
    end
  end
end
