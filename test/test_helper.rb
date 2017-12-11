require "bundler/setup"
Bundler.require(:default)
require "minitest/autorun"
require "minitest/pride"
require "active_record"
require "active_job"

ActiveJob::Base.logger.level = :warn

# to debug
if ENV["VERBOSE"]
  ActiveRecord::Base.logger = ActiveSupport::Logger.new(STDOUT)
end

ActiveRecord::Base.establish_connection(
  adapter: "postgresql_makara",
  makara: {
    sticky: true,
    connections: [
      {
        role: "master",
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

def current_database
  ActiveRecord::Base.connection.execute("SELECT current_database()").first["current_database"].split("_").last
end
