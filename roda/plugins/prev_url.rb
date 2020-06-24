class Roda
  module RodaPlugins

    module PrevUrl

      module RequestMethods

        def save_prev_url(url=nil)
          scope.session['prev_url'] = url || scope.request.referer
        end
        
      end
        
      module InstanceMethods
        
        def prev_url()
          session['prev_url'].to_s.strip.empty? ? nil : session['prev_url']
        end
        
      end
    
    end

    register_plugin(:prev_url, PrevUrl)
  end
end
