# in a haml view:
#
# - BS3Form.new(@article) do |f|
#   = f.form(create_article_path, update_article_path(@article))
#   = f.tinymce_inlite :body
#   = f.input :password, :input_type=>'password'
#   = f.submit
#   = f.endform
#   
# or automatic
# 
# - BS3Form.new(@article).auto(create_path, update_path, :except=>[:lastmod], :csrf_tag=>csrf_tag)
#
# or 
#
# - BS3Form.new(@article).auto(create_path, update_path, :cols=>[:body, :perex], :csrf_tag=>csrf_tag)
#
# or 
#
# - BS3Form.new(@article).auto(create_path, update_path, :cols=>[:body, :perex, :password], :password=>{:input_type=>'password'})
# 
# or just (all columns by default)
#
# - BS3Form.new(@article).auto(create_path, update_path, :password=>{:input_type=>'password'})
#

class BS3Form
  
  class << self
  
    def input(parent,c,o)
      %Q( <input type='#{o[:input_type]||'text'}' name='#{o[:name]}' value='#{h(o[:value])}' id='#{bs3id_for(c,parent.model)}' class='form-control #{o[:class]}' #{o[:required]&&'required'} />\n )
    end
    
    alias :text :input
    
    def radio(parent,c,o)
      id = bs3id_for(c,parent.model)
      s = ['checked', nil]
      s.reverse! unless o[:value]
      out = "<div class='%s'>"
      out << "<span id='%s'/>" # for errors highlighting (radios have ids 47-Article-is_top-yes and 47-Article-is_top-no
      out << "<input type='radio' name='%s' value='true' id='%s-yes' %s /> <label for='%s-yes'>#{h (parent.t(:radio_yes))}</label> "
      out << "<input type='radio' name='%s' value='false' id='%s-no' %s /> <label for='%s-no'>#{h (parent.t(:radio_no))}</label>"
      out << "</div>\n"
      out % [o[:class], id, o[:name], id, s[0], id, o[:name], id, s[1], id]
    end

    def checkbox(parent,c,o)
      id = bs3id_for(c,parent.model)
      s = o[:value] ? 'checked' : ''
      out = "<div class='#{o[:class]}'>"
      out << "<input type='checkbox' name='#{o[:name]}' value='true' id='#{id}' #{s} /> <label for='#{id}'>#{h o[:label]}</label>"
      out << "<input type='hidden' name='#{o[:name_hidden]}' value='' />"
      out << "</div>\n"
    end
    
    def textarea(parent,c,o)
      "<textarea name='%s' id='%s' class='form-control %s' %s>%s</textarea>\n" % [o[:name], bs3id_for(c,parent.model), o[:class], o[:required]&&'required', h(o[:value])]
    end
    
    def tinymce(parent,c,o)
      # it's like the :textarea, but with tinymce class and no 'required' attribute - bootstrap's validator does not work with the tinymced textarea
      # it has to be validated by ajax
      "<textarea name='%s' id='%s' class='form-control tinymce %s'>%s</textarea>\n" % [o[:name], bs3id_for(c,parent.model), o[:class], o[:value]]
    end

    def tinymce_inlite(parent,c,o)
      # bootstrap's 'required' (validator) can't be used on the hidden textarea
      # it has to be validated by ajax
      %Q( <textarea name="#{o[:name]}" id="#{bs3id_for(c,parent.model)}" class='hidden'>#{o[:value]}</textarea><div class='tinymce form-control #{o[:class]}' id='ed-#{bs3id_for(c,parent.model)}'>#{o[:value]}</div> )
    end
    
    def date(parent,c,o)
      o[:value] = o[:value].strftime("%Y-%m-%d") if o[:value]
      o[:required] = "yyyy-mm-dd"
      input(parent,c,o)
    end
    
    def time(parent,c,o)
      o[:value] = o[:value].strftime("%T") if o[:value]
      o[:required] = "hh:mm:ss"
      input(parent,c,o)
    end
    
    def datetime(parent,c,o)
      o[:value] = o[:value].strftime("%Y-%m-%d %T") if o[:value]
      o[:required] = "yyyy-mm-dd hh:mm:ss"
      input(parent,c,o)
    end
    
    # use cztodatetime() to parse this
    def czdatetime(parent,c,o)
      o[:value] = o[:value].strftime('%d.%m.%Y %H:%M') if o[:value]
      input(parent,c,o)
    end

    # bootstrap's 'required' validator can't be used on file input (may be empty if already uploaded)
    # the required, if false, just prints a delete checkbox 
    # presence of the upload must be validated in the model
    def upload(parent,c,o)
      s = ''
      if parent.model.uploaded?(c)
        img_url = parent.model.img_url(c)
        id = bs3id_for(c,parent.model)
        s << "<br/><img src='#{img_url}?#{::Time.now.to_i.to_s}' />\n"
        if ! o[:required]
          s << "<input type='checkbox' name='model[#{c}-delete_upload]' id='#{id}-delete_upload'/> <label for='#{id}-delete_upload'>#{parent.t(:delete_upload)}</label>\n"
        end
      end
      s << "<input type='file' name='%s' id='%s' class='%s' />\n" % [o[:name], id, o[:class]]
      s
    end
    
    def select(parent,c,o)
      out = "<select name='%s' id='%s' class='form-control %s'>\n" % [o[:name], bs3id_for(c,parent.model), o[:class]]
      raise "no select_options given" unless o[:select_options]
      o[:select_options] = parent.__send__(o[:select_options]) unless o[:select_options].kind_of?(Array)
      if o[:select_options].kind_of?(Array)
        o[:select_options].each do |op|
          label,val = op.kind_of?(Array) ? [op[1],op[0]] : [op,op]
          selected = 'selected' if val==o[:value]
          out << "<option value='%s' %s>%s</option>\n" % [h(val),selected,label]
        end
      end
      out << "</select>\n"
    end
    
    # if not enough, use the select above instead and give it exact options
    def many_to_one(parent,c,o)
      parent_class = parent.model.class.association_reflection(c.to_s.sub(/_id$/,'').to_sym).associated_class
      label_method = o[:label_method] || [:title, :label, :name, :login].find{|col| parent_class.instance_methods.include?(col)}
      raise "no label_method resolved" unless label_method
      rows = o[:rows] || parent_class.all
      
      dd = rows.inject([]) do |out,row|
        out.push([row.id, "<option value='#{row.id}' ", ">#{row.send(label_method)}</option>\n"])
      end
      
      option_list = dd.inject("<option value=''>---</option>\n") do |out, row|
        selected = 'selected' if row[0]==o[:value]
        "%s%s%s%s" % [out, row[1], selected, row[2]]
      end
      
      "<select name='%s' id='%s' class='form-control %s'>%s</select>\n" % [o[:name], bs3id_for(c,parent.model), o[:class], option_list]
    end
    
    def submit(parent,c,o)
      o[:value] = o[:value] ? parent.t(o[:value]) : (parent.model.new? ? parent.t(:submit_new) : parent.t(:submit_edit))
      %Q( <input type="submit" name="#{o[:name]}" value="#{h(o[:value])}" id="#{bs3id_for(c,parent.model)}" class="#{o[:class]}" />\n )
    end
    
    # What represents a required field
    def bs3field_required; "<span class='required'> *</span>"; end

    def bs3id_for(col, model); "%s-%s-%s" % [model.id||'new',model.class.name,col]; end
    
    def xsubmit_form_errors(model)
      hsh = {}
      model.errors.each do |k,ary|
        hsh[bs3id_for(k, model)] = ary.join("<br/>")
      end
      # reset previous errors which are not errors anymore
      model.columns.each do |k|
        hsh[bs3id_for(k, model)] = nil unless hsh[bs3id_for(k, model)]
      end
      hsh
    end
      
    # parse bs3form field type 'czdatetime'
    # use BS3Form::parse_czdatetime(str) in a model
    def parse_czdatetime(str)
      str=~/^\s*((\d+)\s*\.\s*(\d+)\s*\.(\s*(\d+))?)?(\s+(\d+)\s*:\s*(\d+)(\s*:\s*(\d+))?)?\s*$/
      now = Time.now
      raise ArgumentError.new("parse_czdatetime: bad input: #{str}") if !$1
      day = $2 || now.day
      month = $3 || now.month
      year = $5 || now.year
      if $6
        hour = $7
        min = $8
        sec = $10
      else
        hour = 0
        min = 0
        sec = 0
      end
      Time.local(year.to_i,month.to_i,day.to_i,hour.to_i,min.to_i,sec.to_i)
    end
    
    private
    
    def h(val)
      CGI::escapeHTML(val.to_s)
    end
    
  end # class << self

  ############
  # instance #
  ############
  
  attr_reader :model
  
  def initialize(model, &block)
    @model = model
    yield(self) if block_given?
  end
  
  # everything undefined becomes bs3field, therefore wrapped into bootstrap-like divs
  def method_missing(name, *args)
    #$log.debug "method_missing called, #{name}", :args=>args
    if ! self.class.respond_to?(name)
      raise "b3form: no method '#{name}'"
    end
    col, o = args
    raise "wrong column definition, should be a Hash, #{o.inspect} given" if o && !o.is_a?(Hash)
    bs3field(col, (o||{}).update(:type=>name))
  end
  
  def form(create_path, update_path, o={})
    enctype = if o[:multipart]
      "enctype='multipart/form-data'"
    elsif o[:enctype]
      "enctype='#{o[:enctype]}'"
    end
    action  = @model.new? ? create_path : update_path
    meth    = @model.new? ? (o[:create_method] || 'post') : (o[:update_method] || 'put')
    %Q( <form action="#{action}" method="post" x-method="#{meth}" #{enctype} class="#{o[:class]}"> )
  end
  
  def endform()
    "</form>"
  end
  
  # hide this by css (00-bs3form.css), check it's presence (crud plugin does that)
  def antispam()
    "<input name='email' id='email-input' value=''/>
     <input name='name' id='name-input' value=''/>
    "
  end
  
  def submit(o={})
    o[:type] = :submit
    bs3input(:submit, o)
  end
  
  # defs example: { :cols=>:all, :except=>[:lastmod, :updated_at], :body=>{:type=>:textarea, :class=>'foobar'} }
  def auto(create_path, update_path, defs={})
    # definition of a column may be Hash, but also just a Symbol - in that case it is the :type; now convert it to hashes
    defs.dup.each { |c,v| v.is_a?(Symbol) && defs[c] = {:type=>v} unless [:cols,:except].include?(c)}
    if ! defs[:cols] || defs[:cols] == :all
      defs[:cols] = @model.columns.dup
      defs[:cols].delete(:id)
      # delete all associations unless defined explicitely as a column (of type select, etc.)
#       defs[:cols].delete_if { |c| @model.class.associations.index(c.to_s.gsub(/_id$/,'').to_sym) && !defs[c]}
    end
    if defs[:except]
      defs[:cols].delete_if { |c| defs[:except].index(c) }
    end
    # associations (many_to_one parent select, etc., otherwise remove the key unless explicitely defined 
    defs[:cols].dup.each do |k,v|
      if assoc = @model.class.association_reflections[k.to_s.gsub(/_id$/,'').to_sym]
        if assoc[:type] == :many_to_one
          defs[k] ||= {}
          defs[k].merge!(:type=>:many_to_one)
        else
          defs.delete(k) unless defs[k] # explicitely defined as something
        end
      end
    end
    fields = defs[:cols].inject(""){|out,c|out << bs3field(c, defs[c] || {})}
    defs[:form] ||= {}
    defs[:form][:multipart] ||= fields =~ /type='file'/
    s = form(create_path, update_path, defs[:form])
    s << antispam
    s << fields
    s << submit(defs[:submit] || {})
    s << defs[:csrf_tag] if defs[:csrf_tag]
    s << endform()
    s
  end
  
  # bs3field is bs3input but with label+error
  def bs3field(col, o={})
    error_list = @model.errors.on(col).join(', ') if !@model.errors.on(col).nil?
    o[:required] = o[:required]==true ? self.class.bs3field_required : o[:required]
    
    %Q( <div class="form-group #{error_list&&'has-error'}"><label for="#{self.class.bs3id_for(col, @model)}">#{t(o[:label] || col)}#{o[:required]||''}</label> #{bs3input(col, o)}<span class="help-block with-errors">#{error_list}</span></div>)
  end
  
  def bs3input(col, o={})
    o[:name] ||= "model[#{col}]"
    o[:required] = o[:required]==true ? self.class.bs3field_required : o[:required]
    if o[:value]==nil && o[:type]!=:submit
      raise "model #{@model.class} probably missing column #{col}" unless @model.respond_to?(col)
      o[:value] = @model.__send__(col)
    end
    if ! o[:type]
      schema = @model.db_schema
      o[:type] = if schema[col][:db_type].to_s.downcase == 'boolean'
        :radio
      elsif schema[col][:db_type].to_s.downcase == 'timestamp'
        :datetime
      elsif schema[col][:db_type].to_s.downcase == 'text'
        :textarea
      elsif @model.class.respond_to?(:upload_reflection) && @model.class.upload_reflection.has_key?(col)
        :upload
      else
        :input
      end
    end
    if o[:type]==:checkbox
      o[:name_hidden] ||= "model[#{col}_hidden]"
    end
    self.class.__send__(o[:type],self,col,o)
  end
  
  def t(col)
    if @model.respond_to?(:t)
      @model.t(col)
    else
      col.to_s
    end
  end
  
end

__END__

these can be used to detect default types:

model.methods
--------------

associations
{:author=>#1, :username=>"Admin", :password=>"$2a$10$v0nDTK5jC5qag1VrUOb6be9E8lgM78kKQ5hsRp8uJyvGhiGi7Wfq.", :email=>"", :is_admin=>true}>} 

db_schema
{:id=>{:allow_null=>false, :default=>nil, :db_type=>"integer", :primary_key=>true, :auto_increment=>true, :type=>:integer, :ruby_default=>nil}, :author_id=>{:allow_null=>true, :default=>nil, :db_type=>"integer", :primary_key=>false, :type=>:integer, :ruby_default=>nil}, :lastmod=>{:allow_null=>true, :default=>nil, :db_type=>"timestamp", :primary_key=>false, :type=>:datetime, :ruby_default=>nil}, :date=>{:allow_null=>true, :default=>nil, :db_type=>"timestamp", :primary_key=>false, :type=>:datetime, :ruby_default=>nil}, :updated_at=>{:allow_null=>true, :default=>nil, :db_type=>"timestamp", :primary_key=>false, :type=>:datetime, :ruby_default=>nil}, :title=>{:allow_null=>true, :default=>nil, :db_type=>"varchar(255)", :primary_key=>false, :type=>:string, :ruby_default=>nil, :max_length=>255}, :perex=>{:allow_null=>true, :default=>nil, :db_type=>"Text", :primary_key=>false, :type=>:string, :ruby_default=>nil}, :body=>{:allow_null=>true, :default=>nil, :db_type=>"Text", :primary_key=>false, :type=>:string, :ruby_default=>nil}, :keywords=>{:allow_null=>true, :default=>nil, :db_type=>"varchar(255)", :primary_key=>false, :type=>:string, :ruby_default=>nil, :max_length=>255}, :photo=>{:allow_null=>true, :default=>nil, :db_type=>"varchar(255)", :primary_key=>false, :type=>:string, :ruby_default=>nil, :max_length=>255}, :is_visible=>{:allow_null=>true, :default=>"0", :db_type=>"Boolean", :primary_key=>false, :type=>:boolean, :ruby_default=>false}} 


model.class.methods
-------------------

upload_reflection
{:photo=>{:default=>[#, "jpg"], :thumb=>[#, "jpg"], :filename_from=>:title}} 

associations
[:author, :article_photos] 

all_association_reflections
[#:User>, #] 

association_reflections
{:author=>#:User>, :article_photos=>#} 
