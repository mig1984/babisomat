# sorry jako, ale tohle je hrozna prasarna :-)
# v planu je vylepseni, tohle je proof of concept

class WebApp < App
  
  plugin :render, :engine=>'haml', :views=>'views/web'
  plugin :assets_preloading
  plugin :request_headers
  plugin :default_headers
  plugin :json
  plugin :json_parser
#  plugin :flash
  plugin :halt
  plugin :sinatra_helpers # send_file
  plugin :html_helpers
  
  route do |r|
  
    @url_host = ENV['URL_HOST']
    ruri = request.env['REQUEST_URI'].gsub(/\?$/,'')  # trailing ?
    @self_url = File.join(@url_host, ruri)
    @web_url = @self_url.gsub(/^\/m/,'/')   # with domain, etc.

    @chapter = nil

    r.root do
      redirect '/svedska-trojka-ovm'
    end

    if ruri == '/svedska-trojka-ovm'
      @toggle = []
      @chapter = 'ovm'
    elsif ruri == '/uvolnovani-rozvolnovani'
      @toggle = ['alzbeta']
      @chapter = 'uvolnovani'
    elsif ruri == '/epr-krambl-paj'
      @toggle = ['alzbeta', 'aplaus']
      @chapter = 'epr_paj'
    end

    r.on @chapter?true:false do
      sources = {}
      bsources = {}
      tvpics = {}
      loops = {}
      Dir['public/web/audio/*'].each do |x|
        if File.directory?(x)
          k = File.basename(x)
          
          v = Dir.open(x).entries.length-5 # ., .., b, tv, loop
          sources[k] = v
          
          v = Dir.open(x+'/loop').entries.length-2 # ., ..
          if v>0
            loops[k] = true
          end
          
          v = Dir.open(x+'/b').entries.length-2 # ., ..
          bsources[k] = v
          
          tvpics[k] = []
          Dir.open(x+'/tv').entries.sort_by{|x| x.to_i}.each do |e| # order in the array must be preserved
            next if e =~ /^\./
            v = Dir.open(x+'/tv/'+e).entries.length-2 # ., ..
            tvpics[k] << v
          end
          
        end
      end
      
      @sources = sources.to_json
      @bsources = bsources.to_json
      @tvpics  = tvpics.to_json
      @loops = loops.to_json
      
      view 'index'
    end
    
  end

  freeze unless ENV['ENVIRONMENT']=='development'
end
