require "makara"
require "distribute_reads/appropriate_pool"
require "distribute_reads/cache_store"
require "distribute_reads/global_methods"
require "distribute_reads/version"

module DistributeReads
  class TooMuchLag < StandardError; end
  class NoReplicasAvailable < StandardError; end

  class << self
    attr_accessor :default_to_primary
    attr_accessor :default_options
  end
  self.default_to_primary = true
  self.default_options = {
    failover: true,
    lag_failover: false
  }

  def self.lag(connection: nil)
    connection ||= ActiveRecord::Base.connection
    if %w(PostgreSQL PostGIS).include?(connection.adapter_name)
      if connection.instance_variable_get(:@slave_pool).connections.size > 1
        warn "[distribute_reads] Multiple replicas available, lag only reported for one"
      end

      connection.execute(
        "SELECT CASE
          WHEN NOT pg_is_in_recovery() OR pg_last_xlog_receive_location() = pg_last_xlog_replay_location() THEN 0
          ELSE EXTRACT (EPOCH FROM NOW() - pg_last_xact_replay_timestamp())
        END AS lag"
      ).first["lag"].to_f
    else
      raise "Option not supported with this adapter"
    end
  end
end

Makara::Proxy.send :prepend, DistributeReads::AppropriatePool
Object.send :include, DistributeReads::GlobalMethods

ActiveSupport.on_load(:active_job) do
  require "distribute_reads/job_methods"
  include DistributeReads::JobMethods
end
