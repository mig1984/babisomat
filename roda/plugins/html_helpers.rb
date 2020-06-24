require 'uri'
require 'iconv'
require 'rack/utils'

class Roda
  module RodaPlugins

    module HTMLHelpers

      def self.load_dependencies(app)
        app.plugin :h
      end

      module InstanceMethods

        # path: string or array
        def build_url(path, params={})
          if path.is_a?(Array)
            path = path.map {|x| u x }.join('/')
          end
          query = ''
          if !params.empty?
            query = '?' + Rack::Utils.build_query(params)
          end
          path + query
        end

        # escape URL
        def u(str)
          ::URI.encode_www_form_component(str)
        end

        # escape javascript
        def j(x)
          x.to_s.gsub(/"/,'\\"').gsub(/'/,"\\\\'")
        end

        def mkattrs(attrs)
          attrs.collect {|k,v| "#{h k}=\"#{h v}\"" }.join(' ')
        end
        
        def mkurltitle( str )
          str = ::Iconv.new('ascii//translit', 'utf-8').iconv(str)
          str.gsub(/\s+/,'-').gsub(/[^\w\d-]+/,'').gsub(/-+/,'-').downcase
        end
        
      end
    
    end

    register_plugin(:html_helpers, HTMLHelpers)
  end
end
