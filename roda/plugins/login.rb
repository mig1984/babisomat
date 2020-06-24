class Roda
  module RodaPlugins
    module Login
      
      def self.load_dependencies(app)
        app.plugin :render
        app.plugin :flash
        app.plugin :json
        app.plugin :path
        app.plugin :type_routing
      end
      
      module ClassMethods
        
        def login_paths()
          ['', '_json'].each do |type|
            ext = type=='' ? '' : '.json'          
            path("login#{type}", :add_script_name=>true) do 
              "/login" << ext
            end
            path("logout#{type}", :add_script_name=>true) do 
              "/logout" << ext
            end
          end
        end
        
      end
      
      module RequestMethods
        
        def login()
          
          prefix = matched_path
          
          is 'login' do
        
            # login: GET /admin/login
            get do
              scope.view 'login'
            end
            
            # do login: POST /admin/login
            post do
              html do
                if scope.user_login(self['model']['login'], self['model']['password'])
                  redirect self['path'] || prefix
                else
                  scope.flash[:error] = 'Heslo nebo uživatelské jméno je blbě!'
                  redirect scope.login_path
                end
              end
              json do
                if scope.user_login(self['model']['login'], self['model']['password'])
                  {:location=>self['path'] || prefix}
                else
                  {'html'=>{'.error-message'=>'Uživatelské jméno nebo heslo je chybně.'}}
                end
              end
            end
            
          end
                  
          # logout: GET /admin/logout
          get 'logout' do
            scope.user_logout()
            html do
              redirect self['path'] || prefix
            end
            json do
              {:location=>self['path'] || prefix}
            end
          end
          
        end

      end
      
      module InstanceMethods

        def session()
          request.env['rack.session']
        end
        
        def user_login(login, password)
          if user = User::authenticate(login, password)
            $log.info "LOGIN: #{login}, IP #{request.env['HTTP_X_FORWARDED_FOR']}"
            session[:user] = user
            return user
          end
          false # default
        end

        def logged_in?
          user().is_a?(User)
        end

        def user()
          session[:user]
        end

        def user_logout()
          session.delete(:user)
        end
        
        def user_reload()
          raise "not logged in" unless session[:user]
          session[:user] = User[user.id]
        end
        
      end
    end
    
    register_plugin(:login, Login)
  end
end

