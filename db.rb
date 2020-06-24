require_relative 'base'
require 'sequel'

DB = Sequel.connect(DATABASE_URL, :loggers => $log)
DB.sql_log_level = :debug
