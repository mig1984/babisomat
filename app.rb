require_relative 'models'
require 'roda'
require 'yuicompressor'
require 'securerandom'

class App < Roda

  ass = lambda do |dir|
    ary = Dir.open("assets/#{dir}").entries
    ary.delete('.')
    ary.delete('..')
    ary.sort!
  end

  if ENV['ENVIRONMENT']=='development' && !ENV['PRECOMPILE_ASSETS']
     plugin :assets,
     :group_subdirs=>true,
     :css => {:web=>ass.call('css/web'), :admin=>ass.call('css/admin')},
     :js => {:web=>ass.call('js/web'), :admin=>ass.call('js/admin')},
     :css_compressor=>:none,
     :js_compressor=>:none
  else
     plugin :assets,
     :group_subdirs=>true,
     :gzip=>true,
     :css => {:web=>ass.call('css/web'), :admin=>ass.call('css/admin')},
     :js => {:web=>ass.call('js/web'), :admin=>ass.call('js/admin')},
     :precompiled=>'precompiled_assets.json',
     :css_compressor=>:yui,
     :js_compressor=>:yui
  end

  if ENV['PRECOMPILE_ASSETS']
    
    Dir['public/assets/*'].each { |x| File.unlink(x) }
    compile_assets
    
  else
    
    if ! File.exists?('precompiled_assets.json')
      raise "no precompiled assets found" 
    end

    plugin :default_headers,
      'Content-Type'=>'text/html; charset=utf8',
  #    'Content-Security-Policy'=>"default-src 'self' https://oss.maxcdn.com/ https://maxcdn.bootstrapcdn.com https://ajax.googleapis.com",  # this disallows also inline scripts
      #'Strict-Transport-Security'=>'max-age=16070400;', # Uncomment if only allowing https:// access
      'X-Frame-Options'=>'sameorigin',
      'X-Content-Type-Options'=>'nosniff',
      'X-XSS-Protection'=>'1; mode=block'

    Unreloader.require('apps')

    route do |r|

      r.assets

      r.is 'robots.txt' do
        File.open('./public/robots.txt').read
      end

      r.on 'public' do
        r.run Rack::File.new('./public')
      end
      
      r.on 'assets' do
        r.run Rack::File.new('./public/assets')
      end

      #r.on 'admin' do
      #    r.run AdminApp.app
      #end

      r.run WebApp.app
      
    end
    
  end
   
  freeze unless ENV['ENVIRONMENT']=='development'
end

