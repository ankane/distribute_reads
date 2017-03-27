require "bundler/setup"
Bundler.require(:default)
require "minitest/autorun"
require "minitest/pride"
require "active_record"

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
