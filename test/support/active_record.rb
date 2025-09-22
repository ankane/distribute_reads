require "active_record"

logger = ActiveSupport::Logger.new(ENV["VERBOSE"] ? STDOUT : nil)
ActiveRecord::Base.logger = logger
# Makara::Logging::Logger.logger = logger
ActiveRecord::Migration.verbose = ENV["VERBOSE"]

ActiveRecord::Base.establish_connection(
  adapter: "#{adapter}_makara",
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

# create table on replica as well
distribute_reads(replica: true) do
  ActiveRecord::Migration.create_table :users, force: true do |t|
    t.string :name
  end
end

class User < ActiveRecord::Base
end
