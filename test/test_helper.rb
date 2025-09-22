require "bundler/setup"
Bundler.require(:default)
require "minitest/autorun"
require "minitest/pride"

require_relative "support/active_record"
require_relative "support/active_job"

def insert_value
  User.create!(name: "Boom")
end

def current_database(prefix: nil)
  func = adapter == "mysql2" ? "database" : "current_database"
  ActiveRecord::Base.connection.select_all("#{prefix}SELECT #{func}()").rows.first.first.split("_").last
end
