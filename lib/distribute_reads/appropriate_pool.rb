module DistributeReads
  module AppropriatePool
    def roles_for(...)
      if Thread.current[:distribute_reads]
        if Thread.current[:distribute_reads][:replica]
          [reading_role]
        elsif Thread.current[:distribute_reads][:primary]
          [writing_role]
        else
          super
        end
      elsif !DistributeReads.by_default
        [writing_role]
      else
        super
      end
    end

    def recent_write_to_primary?(...)
      Thread.current[:distribute_reads] ? false : super
    end

    def connection_for(role, ...)
      return super if role == writing_role

      begin
        super
      rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished
        failover = Thread.current[:distribute_reads] ? Thread.current[:distribute_reads][:failover] : true
        raise if failover == false
        DistributeReads.log "No replicas available. Falling back to primary."
        super(writing_role, ...)
      end
    end

    # defer error handling to connection_for
    def checkout_replica_connection
      replica_pool.checkout(proxy_checkout_timeout)
    end

    def update_primary_latest_write_timestamp(...)
      return if !DistributeReads.by_default
      super
    end
  end
end
