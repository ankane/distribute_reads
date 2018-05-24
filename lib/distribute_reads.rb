require "makara"
require "distribute_reads/appropriate_pool"
require "distribute_reads/global_methods"
require "distribute_reads/version"

module DistributeReads
  class Error < StandardError; end
  class TooMuchLag < Error; end
  class NoReplicasAvailable < Error; end

  class << self
    attr_accessor :by_default
    attr_accessor :default_options
  end
  self.by_default = false
  self.default_options = {
    failover: true,
    lag_failover: false
  }

  def self.replication_lag(connection: nil)
    distribute_reads do
      lag(connection: connection)
    end
  end

  def self.lag(connection: nil)
    raise DistributeReads::Error, "Don't use outside distribute_reads" unless Thread.current[:distribute_reads]

    connection ||= ActiveRecord::Base.connection

    replica_pool = connection.instance_variable_get(:@slave_pool)
    if replica_pool && replica_pool.connections.size > 1
      warn "[distribute_reads] Multiple replicas available, lag only reported for one"
    end

    if %w(PostgreSQL PostGIS).include?(connection.adapter_name)
      # cache the version number
      @server_version_num ||= {}
      cache_key = connection.pool.object_id
      @server_version_num[cache_key] ||= connection.execute("SHOW server_version_num").first["server_version_num"].to_i

      lag_condition =
        if @server_version_num[cache_key] >= 100000
          "pg_last_wal_receive_lsn() = pg_last_wal_replay_lsn()"
        else
          "pg_last_xlog_receive_location() = pg_last_xlog_replay_location()"
        end

      connection.execute(
        "SELECT CASE
          WHEN NOT pg_is_in_recovery() OR #{lag_condition} THEN 0
          ELSE EXTRACT (EPOCH FROM NOW() - pg_last_xact_replay_timestamp())
        END AS lag".squish
      ).first["lag"].to_f
    elsif %w(MySQL Mysql2 Mysql2Spatial Mysql2Rgeo).include?(connection.adapter_name)
      replica_value = Thread.current[:distribute_reads][:replica]
      begin
        # makara doesn't send SHOW queries to replica, so we must force it
        Thread.current[:distribute_reads][:replica] = true
        status = connection.exec_query("SHOW SLAVE STATUS").to_hash.first
        status ? status["Seconds_Behind_Master"].to_f : 0.0
      ensure
        Thread.current[:distribute_reads][:replica] = replica_value
      end
    else
      raise DistributeReads::Error, "Option not supported with this adapter"
    end
  end

  # legacy
  def self.default_to_primary
    !by_default
  end

  # legacy
  def self.default_to_primary=(value)
    self.by_default = !value
  end
end

Makara::Proxy.send :prepend, DistributeReads::AppropriatePool
Object.send :include, DistributeReads::GlobalMethods

ActiveSupport.on_load(:active_job) do
  require "distribute_reads/job_methods"
  include DistributeReads::JobMethods
end
