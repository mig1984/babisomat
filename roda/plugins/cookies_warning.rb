class Roda
  module RodaPlugins

    module CookiesWarning

      def self.load_dependencies(app)
        app.plugin :type_routing
      end
      
      module ClassMethods
        
        def cookies_warning_paths()
          path('cookies_warning', :add_script_name=>true) do
            '/cookies_warning.json'
          end
        end
     
      end
      
      module RequestMethods

        def cookies_warning()
          on 'cookies_warning' do
            post do
              json do
                scope.session['cookies_warning'] = true
                {}
              end
            end
            html do
              'not implemented'
            end
          end
        end

      end
      
    end

    register_plugin(:cookies_warning, CookiesWarning)
  end
end

