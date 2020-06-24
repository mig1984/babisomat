desc "Precompile assets"
task :precompile_assets do
  ENV['PRECOMPILE_ASSETS'] = '1'
  require './app.rb'
end
