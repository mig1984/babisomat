require 'iconv'

# need BS3Form

class Roda
  module RodaPlugins

    module CRUD

      def self.load_dependencies(app)
        app.plugin :render
        app.plugin :flash
        app.plugin :halt
        app.plugin :json
        app.plugin :path
        app.plugin :all_verbs
        app.plugin :type_routing
        app.plugin :with_all_directories
      end
      
      module ClassMethods
        
        # list:    GET     articles_path
        # new:     GET     new_article_path
        # create:  POST    create_articles_path
        # edit:    GET     edit_article_path(id)
        # show:    GET     show_article_path(id)
        # update:  PUT     update_article_path(id)
        # delete:  DELETE  delete_article_path(id)
        # + json_path versions
        
        def crud_paths(model_class, urlname=nil, custom_actions=[])
          name = model_class.instance_exec { underscore(demodulize(self.name)) }
          name_plural = model_class.instance_exec { pluralize(underscore(demodulize(self.name))) }
          urlname ||= name_plural
          # list: when html -> directories
          path("#{name_plural}", :add_script_name=>true) do |*filter|
            File.join('/',urlname, (filter.empty? ? instance_variable_get("@filter_#{name}").to_s : filter.join), '/' ).gsub(/\/+$/,'/')
          end
          # list: when json, -> directories/list.json
          path("#{name_plural}_json", :add_script_name=>true) do |*filter|
            File.join('/',urlname, (filter.empty? ? instance_variable_get("@filter_#{name}").to_s : filter.join), '/list.json' )
          end          
          ['', '_json'].each do |type|  
            ext = type=='' ? '.html' : '.json'
            [:new, :create].each do |met|
              path("#{met}_#{name}#{type}", :add_script_name=>true) do |*args|
                parent = args[0]
                # copying filter from the parent is necessary when multiple categories are listed and we wan't to reply on a post
                # (the list's filter, i.e. @filter_name may be empty in that case)
                filter = parent ? parent.filter : instance_variable_get("@filter_#{name}").to_s
                x = File.join('/',urlname, filter, 'new' )
                x << ext                
                # :new can pass a parent, it will generate :create path with the parent_id (or the parent can be passed to the :create as well)
                if parent
                  x << "?parent_id=#{parent.id}"
                elsif request['parent_id']
                  x << "?parent_id=#{request['parent_id']}" 
                end
                x
              end
            end
            [:edit, :update].each do |met|
              path("#{met}_#{name}#{type}", :add_script_name=>true) do |item| 
                File.join('/',urlname, item.filter, "#{item.id}-#{item.url_title}_edit") << ext
              end
            end
            custom_actions.each do |met|
              path("#{met}_#{name}#{type}", :add_script_name=>true) do |item| 
                File.join('/',urlname, item.filter, "#{item.id}-#{item.url_title}_#{met}") << ext
              end
            end            
            [:show, :delete].each do |met|
              path("#{met}_#{name}#{type}", :add_script_name=>true) do |item| 
                File.join('/',urlname, item.filter, "#{item.id}-#{item.url_title}") << ext
              end
            end
          end # type
        end
     
      end
      
      module RequestMethods
               
        #   opts[:name]            # self name
        #   opts[:urlname]         # name in url
        #   opts[:new_item]        # lambda returning a new item object
        #   opts[:list_dataset_filter] # lambda to filter items and set instance variables
        #   opts[:before]   # lambda
        def crud(model_class, opts={}, &block)
          
          name = model_class.instance_exec { underscore(demodulize(self.name)) }
          name_plural = model_class.instance_exec { pluralize(underscore(demodulize(self.name))) }
          urlname = opts[:urlname] || name_plural
          default_newitem = lambda { model_class.new }
          
          on urlname do
            
            # if URL is "/forums/foo/bar/11", then the filter is "foo/bar"
            #on lambda { consume(/\A(.*)(?=\/[^\/]+\.(json|html)\z)/) } do |filter|  # filter == '' | '/foo' | '/foo/bar'
            
            with_all_directories do |filter|
              
              filter = ::Iconv.new('ascii//translit', 'utf-8').iconv(filter)  # otherwise "napady" != "napady"
              filter.gsub!(/^\/+/,'')
              filter.gsub!(/\/+$/,'')
              scope.instance_variable_set("@filter_#{name}", filter)  # used in named routes; has to work only among own named routes
              $log.debug "filter is: #{filter}"
              
              # shared updater
              updater = proc do |action,item,filter,opts|
                
                # nothing has changed? (if there is just a file input and you let it empty, self['model'] is not sent at all 
                unless self['model']
                  path = scope.send("#{name_plural}_path") << '#' << item.id.to_s
                  json do
                    {'location'=>path}
                  end
                  html do 
                    redirect path
                  end
                end
                
                self['model'].delete('submit')
                $log.debug "going to update", :parent_id=>self[:parent_id], :model=>self['model']
                begin
                  if item.respond_to?(:parent_id) && self[:parent_id]      # tree-like model
                    item.parent_id = self[:parent_id]
                  end
                  item.update(self['model'])
                  opts[:after].call(action, item, filter) if opts[:after]
                rescue
                  $log.error $!, $!.backtrace
                  json do
                    {'form_errors'=>BS3Form::xsubmit_form_errors(item), 'flash_error'=>'Jsou tam chyby.'}
                  end
                  html do
                    '' # TODO
                  end
                else
                  path = scope.send("#{name_plural}_path") << '#' << item.id.to_s
                  scope.flash[:notice] = "Uloženo jest."
                  json do
                    {'location'=>path}
                  end
                  html do 
                    redirect path
                  end
                end
              end  
              
              on 'new' do
                
                # new
                get do
                  opts[:before].call(:new, nil, filter) if opts[:before]
                  item = opts[:new_item] ? opts[:new_item].call() : default_newitem.call # you can set defaults on passed object before                  
                  scope.instance_variable_set("@#{name}", item)
                  
                  json do
                    form = scope.render "#{name}-_form"
                    if self['parent_id']
                      {'html'=>{"#form-#{name}-#{self['parent_id']}"=>form}}
                    else
                      {'html'=>{"#form-#{name}-new"=>form}}
                    end
                  end
                  html do
                    scope.view "#{name}-newedit"
                  end
                end

                # create
                post do
                  redirect('/') if spam?
                  opts[:before].call(:create, nil, filter) if opts[:before]                  
                  item = opts[:new_item] ? opts[:new_item].call() : default_newitem.call
                  updater.call(:create, item, filter, opts) # shared updater
                end
              
              end
                 
              # list: matches both / and /list.json
              get /(list)?/ do
                opts[:before].call(:list, nil, filter) if opts[:before]
                
                dtst = model_class
                
                if opts[:list_dataset_filter]  # to set up other instance vars
                  dtst = opts[:list_dataset_filter].call(dtst) 
                end
                
                # to be able to display a new form inside the list
                new_item = opts[:new_item] ? opts[:new_item].call() : default_newitem.call
                
                scope.instance_variable_set("@#{name}", new_item) 
                scope.instance_variable_set("@#{name_plural}", dtst)

                json do
                  {} # TODO
                end
                html do
                  scope.view(name_plural)
                end
              end
              
              # working on item
              on /(\d+)-(.+?)(_\w+)?/ do |id, url_title, sub_action|
                item = model_class[id.to_i]
                halt 404, 'Sorry, no item found (#1)' unless item
                halt 404, 'Sorry, no item found (#2)' if url_title != item.url_title
                
                sub_action = sub_action.to_s.empty? ? nil : sub_action[1..-1].to_sym
                
                on sub_action==:edit do
              
                  # edit
                  get do
                    opts[:before].call(:edit, item, filter) if opts[:before]
                    scope.instance_variable_set("@#{name}", item)
                    
                    json do
                      form = scope.render "#{name}-_form"
                      {'html'=>{"#form-#{name}-#{id}"=>form}}
                    end
                    html do
                      scope.view "#{name}-newedit"
                    end
                  end
                  
                  # update
                  put do
                    
                    redirect('/') if spam?
                    opts[:before].call(:update, item, filter) if opts[:before]
                    
                    if self['model']
                      # delete upload if checkbox "delete?"
                      self['model'].dup.each do |k,v|
                        if k =~ /(.*?)-delete_upload$/
                          self['model'].delete(k)
                          col = $1
                          self['model'][col] = nil
                        end
                      end
                      
                    end

                    # it is not allowed to change parent
                    self.delete('parent_id')
                    
                    updater.call(:update, item, filter, opts) # shared updater
                  end

                end
              
                on !sub_action do
                
                  # show
                  get do 
                    opts[:before].call(:show, item, filter) if opts[:before]
                    scope.instance_variable_set("@#{name}", item)
                    json do
                      {} # TODO
                    end
                    html do 
                      scope.view "#{name}-show"
                    end
                  end
                  
                  # delete
                  delete do
                    opts[:before].call(:delete, item, filter) if opts[:before]
                    item.destroy
                    json do
                      {'html'=>{"##{id}"=>''}, 'flash_notice'=>'Smazáno jest.'}
                    end
                    html do                    
                      '' # TODO
                    end
                  end
                  
                end
                
                if sub_action && block_given?
                  opts[:before].call(sub_action, item, filter) if opts[:before]
                  yield(sub_action, item, filter)
                end
                
              end
              
            end
          
          end
            
        end

        private
        
        def spam?
          s = self['name'].to_s << self['email'].to_s
          if s.length>0
            $log.info "submitted spam: #{s}"
            true
          else
            false
          end
        end
        
      end
    
    end

    register_plugin(:crud, CRUD)
  end
end

