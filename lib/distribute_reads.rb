# dependencies
require "active_support"
require "makara"

# modules
require "distribute_reads/appropriate_pool"
require "distribute_reads/cache_store"
require "distribute_reads/global_methods"
require "distribute_reads/version"

module DistributeReads
  class Error < StandardError; end
  class TooMuchLag < Error; end
  class NoReplicasAvailable < Error; end

  class << self
    attr_accessor :by_default
    attr_accessor :default_options
    attr_writer :logger
  end
  self.by_default = false
  self.default_options = {
    failover: true,
    lag_failover: false
  }

  def self.logger
    unless defined?(@logger)
      @logger = ActiveRecord::Base.logger
    end
    @logger
  end

  def self.replication_lag(connection: nil)
    connection ||= ActiveRecord::Base.connection

    replica_pool = connection.instance_variable_get(:@slave_pool)
    if replica_pool && replica_pool.connections.size > 1
      if ENV["DISTRIBUTE_READS_VERBOSE"].present? || self.already_logged_multi_replica_warning != true
        log "Multiple replicas available, lag only reported for one"
        self.already_logged_multi_replica_warning = true
      end
    end

    with_replica do
      case connection.adapter_name
      when "PostgreSQL", "PostGIS"
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
      when "MySQL", "Mysql2", "Mysql2Spatial", "Mysql2Rgeo"
        @aurora_mysql ||= {}
        cache_key = connection.pool.object_id

        unless @aurora_mysql.key?(cache_key)
          # makara doesn't send SHOW queries to replica by default
          @aurora_mysql[cache_key] = connection.exec_query("SHOW VARIABLES LIKE 'aurora_version'").to_hash.any?
        end

        if @aurora_mysql[cache_key]
          status = connection.exec_query("SELECT Replica_lag_in_msec FROM mysql.ro_replica_status WHERE Server_id = @@aurora_server_id").to_hash.first
          status ? status["Replica_lag_in_msec"].to_f / 1000.0 : 0.0
        else
          status = connection.exec_query("SHOW SLAVE STATUS").to_hash.first
          if status
            if status["Seconds_Behind_Master"].nil?
              # replication stopped
              # https://dev.mysql.com/doc/refman/8.0/en/show-slave-status.html
              nil
            else
              status["Seconds_Behind_Master"].to_f
            end
          else
            # not a replica
            0.0
          end
        end
      when "SQLite"
        # never a replica
        0.0
      else
        raise DistributeReads::Error, "Option not supported with this adapter"
      end
    end
  end

  def self.log(message)
    logger.info("[distribute_reads] #{message}") if logger
  end

  # private
  def self.with_replica
    previous_value = Thread.current[:distribute_reads]
    begin
      Thread.current[:distribute_reads] = {replica: true, failover: false}
      yield
    ensure
      Thread.current[:distribute_reads] = previous_value
    end
  end

  # private
  def self.makara3?
    unless defined?(@makara3)
      @makara3 = Gem::Version.new(Makara::VERSION.to_s) < Gem::Version.new("0.4.0")
    end
    @makara3
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

Makara::Proxy.prepend DistributeReads::AppropriatePool
Object.include DistributeReads::GlobalMethods

ActiveSupport.on_load(:active_job) do
  require "distribute_reads/job_methods"
  include DistributeReads::JobMethods
end
