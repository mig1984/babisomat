require_relative 'db'

Sequel::Model.db = DB
Sequel::Model.plugin :auto_validations
Sequel::Model.plugin :prepared_statements
Sequel::Model.plugin :defaults_setter
Sequel::Model.plugin :validation_helpers
Sequel::Model.plugin :nested_attributes
Sequel::Model.plugin :association_dependencies
Sequel::Model.plugin :prepared_statements
Sequel::Model.plugin :subclasses
Sequel::Model.plugin :url_title
Sequel::Model.plugin :t

if ENV['ENVIRONMENT'] == 'development'
  Sequel::Model.cache_associations = false
end

unless defined?(Unreloader)
  require 'rack/unreloader'
  Unreloader = Rack::Unreloader.new(:reload=>false)
end
Unreloader.require('models'){|f| Sequel::Model.send(:camelize, File.basename(f).sub(/\.rb\z/, ''))}

if ENV['ENVIRONMENT'] != 'development'
  Sequel::Model.finalize_associations
  Sequel::Model.freeze_descendents
  DB.freeze
end
