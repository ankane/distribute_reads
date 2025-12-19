require "active_record"

logger = ActiveSupport::Logger.new(ENV["VERBOSE"] ? STDOUT : nil)
ActiveRecord::Base.logger = logger
ActiveRecord::Migration.verbose = ENV["VERBOSE"]

options = {}
options[:host] = "127.0.0.1" if adapter == "trilogy"

ActiveRecord::Base.configurations = {
  default_env: {
    primary: {
      adapter: "#{adapter}_proxy",
      database: "distribute_reads_test_primary",
      **options
    },
    replica: {
      adapter: adapter,
      database: "distribute_reads_test_replica",
      replica: true,
      **options
    }
  }
}

ActiveRecord::Base.establish_connection :primary

class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  connects_to database: {writing: :primary, reading: :replica}
end

ActiveRecord::Schema.define do
  create_table :users, force: true do |t|
    t.string :name
  end
end

# create table on replica as well
ActiveRecord::Base.connected_to(role: :reading) do
  ActiveRecord::Base.connection.stub(:preventing_writes?, false) do
    ActiveRecord::Schema.define do
      create_table :users, force: true do |t|
        t.string :name
      end
    end
  end
end

class User < ApplicationRecord
end
