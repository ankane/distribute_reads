require "active_job"

ActiveJob::Base.logger.level = Logger::WARN

class TestJob < ActiveJob::Base
  distribute_reads

  def perform
    $current_database = current_database
  end
end

class ReadWriteJob < ActiveJob::Base
  def perform
    $current_database = current_database
    insert_value
  end
end

