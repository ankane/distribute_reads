require "bundler/setup"
Bundler.require(:default)
require "minitest/autorun"
require "minitest/pride"
require "active_record"
require "active_job"

ActiveJob::Base.logger.level = Logger::WARN

logger = ActiveSupport::Logger.new(ENV["VERBOSE"] ? STDOUT : nil)
ActiveRecord::Base.logger = logger
# Makara::Logging::Logger.logger = logger
ActiveRecord::Migration.verbose = ENV["VERBOSE"]

def adapter
  ENV["ADAPTER"] || "postgresql"
end

ActiveRecord::Base.establish_connection(
  adapter: "#{adapter}_makara",
  makara: {
    sticky: true,
    connections: [
      {
        role: "primary",
        name: "primary",
        database: "distribute_reads_test_primary"
      },
      {
        name: "replica",
        database: "distribute_reads_test_replica"
      }
    ]
  }
)

ActiveRecord::Migration.create_table :users, force: true do |t|
  t.string :name
end

# create table on replica as well
distribute_reads(replica: true) do
  ActiveRecord::Migration.create_table :users, force: true do |t|
    t.string :name
  end
end

class User < ActiveRecord::Base
end

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

def insert_value
  User.create!(name: "Boom")
end

def current_database(prefix: nil)
  func = adapter == "mysql2" ? "database" : "current_database"
  ActiveRecord::Base.connection.select_all("#{prefix}SELECT #{func}()").rows.first.first.split("_").last
end
