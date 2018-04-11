module DistributeReads
  class MysqlReplicationLagReporter
    def initialize(connection)
      @connection = connection
    end

    def lag
      return standard_lag if standard_replica?
      aws_aurora_lag
    end

    private

    def standard_lag
      return 0.0 unless standard_replica?

      status = @connection.exec_query("SHOW SLAVE STATUS").to_hash.first
      status ? status["Seconds_Behind_Master"].to_f : 0.0
    end

    def aws_aurora_lag
      return 0.0 unless aws_aurora?

      # Aurora MySQL does not use MySQL Binary Log File Position Based Replication method for its replication,
      # which is why the SHOW SLAVE STATUS command does not show any information.
      status = @connection.exec_query("SELECT Replica_lag_in_msec FROM mysql.ro_replica_status").to_hash.first
      status ? status["Replica_lag_in_msec"] / 1000.0 : 0.0
    end

    def standard_replica?
      return @standard_replica unless @standard_replica.nil?
      @standard_replica = !@connection.exec_query("SHOW SLAVE STATUS").to_hash.first.nil?
    end

    def aws_aurora?
      return @aws_aurora unless @aws_aurora.nil?
      @aws_aurora = !@connection.exec_query("SHOW TABLES FROM mysql LIKE 'ro_replica_status'").to_hash.first.nil?
    end
  end
end
