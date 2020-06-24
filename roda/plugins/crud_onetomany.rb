require 'iconv'

# need BS3Form

class Roda
  module RodaPlugins

    module CRUDOneToMany

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
        
        # list:    GET     article_photos_path
        # new:     GET     new_article_photo_path
        # create:  POST    create_article_photos_path
        # edit:    GET     edit_article_photo_path(id)
        # show:    GET     show_article_photo_path(id)
        # update:  PUT     update_article_photo_path(id)
        # delete:  DELETE  delete_article_photo_path(id)
        # + json_path versions
        
        def crud_onetomany_paths(model_class, parent_model_class, urlname=nil, custom_actions={})
          name = model_class.instance_exec { underscore(demodulize(self.name)) }
          name_plural = model_class.instance_exec { pluralize(underscore(demodulize(self.name))) }
          parent_name = parent_model_class.instance_exec { underscore(demodulize(self.name)) }
          urlname ||= name_plural
         
          # list: when html -> filter/pid-purltitle/
          path("#{name_plural}", :add_script_name=>true) do |parent| 
            File.join('/',urlname, parent.filter, "#{parent.id}-#{parent.url_title}", '/' ).gsub(/\/+$/,'/')
          end
          # list: when json, -> filter/pid-purltitle/list.json
          path("#{name_plural}_json", :add_script_name=>true) do |parent| 
            File.join('/',urlname, parent.filter, "#{parent.id}-#{parent.url_title}", "list.json" )
          end
          ['', '_json'].each do |type|
            ext = type=='' ? '.html' : '.json'
            [:new, :create].each do |met|
              path("#{met}_#{name}#{type}", :add_script_name=>true) do |parent| 
                File.join('/',urlname, parent.filter, "#{parent.id}-#{parent.url_title}", "new" ) << ext
              end
            end
            [:edit, :update].each do |met|
              path("#{met}_#{name}#{type}", :add_script_name=>true) do |item|
                parent = item.send(parent_name)
                raise "can't get parent" unless parent
                File.join('/',urlname, parent.filter, "#{parent.id}-#{parent.url_title}", "#{item.id}-#{item.url_title}_edit" ) << ext
              end 
            end
            custom_actions.each do |met|
              path("#{met}_#{name}#{type}", :add_script_name=>true) do |item|
                parent = item.send(parent_name)
                raise "can't get parent" unless parent
                File.join('/',urlname, parent.filter, "#{parent.id}-#{parent.url_title}", "#{item.id}-#{item.url_title}_#{met}" ) << ext                
              end
            end               
            [:show, :delete].each do |met|
              path("#{met}_#{name}#{type}", :add_script_name=>true) do |item|
                parent = item.send(parent_name)
                raise "can't get parent" unless parent
                File.join('/',urlname, parent.filter, "#{parent.id}-#{parent.url_title}", "#{item.id}-#{item.url_title}" ) << ext
              end 
            end
          end # type
        end
        
      end

      module RequestMethods

        attr_reader :filter     # is read in templates to detect, if a filter is on, etc.
        
        # crud_onetomany(:article_photo, Article)
        # => /admin/article_photos/...
        # @item or @items in views
        # opts:
        #   opts[:urlname]
        #   opts[:new_item]         proc called with (parent_id, params) to return a new object to be added (you can set defaults in there)
        #   opts[:before]           lambda
        def crud_onetomany(model_class, parent_model_class, opts={})
          
          name = model_class.instance_exec { underscore(demodulize(self.name)) }
          name_plural = model_class.instance_exec { pluralize(underscore(demodulize(self.name))) }
          parent_name = parent_model_class.instance_exec { underscore(demodulize(self.name)) }
          parent_name_plural = parent_model_class.instance_exec { pluralize(underscore(demodulize(self.name))) }
          urlname = opts[:urlname] || name_plural
          default_newitem = lambda { |parent_item| model_class.new() }

          on urlname do
            
            with_all_directories do |dirs|
              
              ary = dirs.split(/\//)
              
              if ary.last =~ /(\d+)-([^\/]+)/
                parent_id = $1.to_i
                parent_url_title = $2
              else
                raise "weird parent in url"
              end
              
              filter = ary[0..-2].join('/')
              filter = ::Iconv.new('ascii//translit', 'utf-8').iconv(filter)  # otherwise "napady" != "napady"                 
              filter.gsub!(/^\/+/,'')
              filter.gsub!(/\/+$/,'')
              scope.instance_variable_set("@filter_#{parent_name}", filter)  # used in named routes; has to work only among own named routes
              $log.debug "filter is: #{filter}"
              
              parent = parent_model_class.where(Sequel[parent_name_plural.to_sym][:id]=>parent_id).first
              halt(404, "Sorry, no item found (#5)") unless parent
              halt 404, 'Sorry, no item found (#6)' if parent_url_title != parent.url_title

              # working on parent
              on 'new' do 
                
                # new
                get do
                  opts[:before].call(:new, parent, nil, filter) if opts[:before]
                  item = opts[:new_item] ? opts[:new_item].call(parent) : default_newitem.call(parent)
                  
                  scope.instance_variable_set("@#{parent_name}", parent)  # for displaying parent's title, etc.
                  scope.instance_variable_set("@#{name}", item)
                  html do
                    scope.view "#{name}-newedit"
                  end
                  json do
                    # TODO
                  end
                end
              
                # create (add)
                post do 
                  opts[:before].call(:create, parent, nil, filter) if opts[:before]                  
                  item = opts[:new_item] ? opts[:new_item].call(parent) : default_newitem.call(parent)
                  
                  begin
                    $log.debug("going to create", self['model'])
                    self['model'].delete('submit')
                    item.update(self['model'])
                    parent.send("add_#{name}", item)
                  rescue
                    $log.error $!, $!.backtrace
                    json do
                      {'form_errors'=>BS3Form::xsubmit_form_errors(item), 'flash_error'=>'Jsou tam chyby.'}
                    end
                    html do
                      '' # TODO
                    end                      
                  else
                    path = scope.send("#{name_plural}_path", parent) #<< '#' << item.id.to_s
                    scope.flash[:notice] = "Uloženo jest."
                    json do
                      {'location'=>path}
                    end
                    html do 
                      redirect path
                    end
                  end
                end
                
              end
              
              # list: matches both / and /list.json
              get /(list)?/ do 
                opts[:before].call(:list, parent, nil, filter) if opts[:before]

                dtst = parent.send(name_plural) # get a model_class
                
                if opts[:list_dataset_filter]  # to set up other instance vars
                  dtst = opts[:list_dataset_filter].call(dtst) 
                end               
                
                new_item = opts[:new_item] ? opts[:new_item].call(parent) : default_newitem.call(parent)
                
                scope.instance_variable_set("@#{parent_name}", parent)    # for displaying parent's title, etc.
                scope.instance_variable_set("@#{name}", new_item)  # to be able to display a new form inside the list
                scope.instance_variable_set("@#{name_plural}", dtst)
                
                html do
                  scope.view(name_plural)
                end
                json do
                  # TODO
                end
              end
              
              # working on item
              on /(\d+)-(.+?)(_\w+)?/ do |id, url_title, sub_action|

                item = model_class.where(Sequel[name_plural.to_sym][:id]=>id).first
                halt 404, 'Sorry, no item found (#1)' unless item
                halt 404, 'Sorry, no item found (#2)' if url_title != item.url_title

                sub_action = sub_action.to_s.empty? ? nil : sub_action[1..-1].to_sym
                                
                on sub_action==:edit do
                  
                  # edit
                  get do
                    opts[:before].call(:edit, parent, item, filter) if opts[:before]
                    scope.instance_variable_set("@#{parent_name}", parent)  # for displaying parent's title, etc.
                    scope.instance_variable_set("@#{name}", item)
                    html do
                      scope.view "#{name}-newedit"
                    end
                    json do
                      # TODO
                    end
                  end
                  
                  # update
                  put do
                    opts[:before].call(:update, parent, item, filter) if opts[:before]

                    if self['model']
                      # delete upload if checkbox "delete?"
                      self['model'].dup.each do |k,v|
                        if k =~ /(.*?)-delete_upload$/
                          self['model'].delete(k)
                          col = $1
                          self['model'][col] = nil
                        end
                      end
                    else
                      # nothing has changed? (if there is just a file input and you let it empty, self['model'] is not sent at all 
                      path = scope.send("#{name_plural}_path", parent) << '#' << item.id.to_s
                      json do
                        {'location'=>path}
                      end
                      html do 
                        redirect path
                      end
                    end
                    
                    # TODO: change position only
                    
                    begin
                      $log.debug("going to update", self['model'])
                      self['model'].delete('submit') 
                      item.update(self['model'])
                    rescue
                      $log.error $!, $!.backtrace
                      json do
                        {'form_errors'=>BS3Form::xsubmit_form_errors(item), 'flash_error'=>'Jsou tam chyby.'}
                      end
                      html do
                        '' # TODO
                      end
                    else
                      path = scope.send("#{name_plural}_path", parent) << "?#{Time.now.to_i}" << '#' << item.id.to_s
                      scope.flash[:notice] = "Uloženo jest."
                      json do
                        {'location'=>path}
                      end
                      html do 
                        redirect path
                      end
                    end
                  end
                
                end
                
                on !sub_action do
                
                  # show
                  get do
                    opts[:before].call(:show, parent, item, filter) if opts[:before]
                    scope.instance_variable_set("@#{name}", item)
                    html do
                      scope.view "#{name}-show"
                    end
                    json do
                      # TODO
                    end
                  end                
                              
                  # delete
                  delete do 
                    opts[:before].call(:delete, parent, item, filter) if opts[:before]
                    item.destroy
                    html do
                      # TODO
                    end
                    json do
                      {'html'=>{"##{id}"=>''}, 'flash_notice'=>'Smazáno jest.'}
                    end
                  end
                
                end
                
                if block_given?
                  opts[:before].call(sub_action, parent, item, filter) if opts[:before]
                  yield(sub_action, parent, item, filter)
                end
                
              end
                
            end
            
          end

        end
          
      end
    
    end

    register_plugin(:crud_onetomany, CRUDOneToMany)
  end
end

