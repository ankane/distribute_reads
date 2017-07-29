require "makara"
require "distribute_reads/appropriate_pool"
require "distribute_reads/global_methods"
require "distribute_reads/version"

module DistributeReads
  class TooMuchLag < StandardError; end

  class << self
    attr_accessor :default_to_primary
  end
  self.default_to_primary = true

  def self.lag
    conn = ActiveRecord::Base.connection
    if %w(PostgreSQL PostGIS).include?(conn.adapter_name)
      conn.execute(
        "SELECT CASE
          WHEN pg_last_xlog_receive_location() = pg_last_xlog_replay_location() THEN 0
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
  extend DistributeReads::JobMethods
end
