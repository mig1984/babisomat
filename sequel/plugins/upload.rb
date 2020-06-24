# usage:
#    plugin :upload
#    upload :document, :filename_from=>:title, :default=>[proc {im_resize(200, 200, '^')}, 'jpg'], :thumb=>[proc {im_resize(200, 200, '^')}, 'jpg']
#
#    the :default style is used when style=nil is passed to the upload_url (does not add the style to the filename)
# 
#    in a view: article.img_url(:document)           => default
#               article.img_url(:document, :thumb)   => thumb
#               article.orig_url(:document)          => original

require 'cgi'
require 'iconv'
require 'fileutils'

module ::Sequel::Plugins::Upload
  
  F = ::File
  D = ::Dir
  FU = ::FileUtils
  
  def self.configure(model, opts={})
    model.instance_eval do
      self.upload_reflection = {}
      self.upload_default_document = opts[:default_document] || './public/document.png'  # used when convert fails
      self.upload_local_root  = opts[:local_root]  || './public/upload'
      self.upload_public_root = opts[:public_root] || '/public/upload'
    end
  end
  
  module ClassMethods
    
    attr_accessor :upload_reflection
    attr_reader :upload_local_root, :upload_public_root, :upload_default_document

    def upload_local_root=(location)
      @upload_local_root = location
      FU.mkdir_p(File.join(location, self.name.to_s))
    end

    def upload_public_root=(location)
      @upload_public_root = location
    end

    def upload_default_document=(location)
      @upload_default_document = location
    end
    
    # Declare a upload entry
    def upload(name, options={})
      @upload_reflection.store name.to_sym, options
      # Exemple of upload hash for col_name:
      # { :type=>"image/jpeg", 
      #   :filename=>"default.jpeg", 
      #   :tempfile=>#<File:/var/folders/J0/J03dF6-7GCyxMhaB17F5yk+++TI/-Tmp-/RackMultipart.12704.0>, 
      #   :head=>"Content-Disposition: form-data; name=\"model[col_name]\"; filename=\"default.jpeg\"\r\nContent-Type: image/jpeg\r\n", 
      #   :name=>"model[col_name]"
      # }
      #
      # SETTER
      define_method name.to_s+'='  do |upload_hash|
        return if upload_hash=="" # File in the form is unchanged
        
        if upload_hash.nil?
          destroy_files_for(name) unless self.__send__(name).nil?
          super('')
        else
          h = {}
          h.merge!(identify(upload_hash[:tempfile].path))
          
          @tempfile_path ||= {}
          @tempfile_path[name.to_sym] = upload_hash[:tempfile].path
          h[:name] = name.to_s << upload_hash[:filename].to_s[/\.[^.]+$/].to_s  # sometimes there is no filename
          h[:type] ||= upload_hash[:type]
          h[:size] = upload_hash[:tempfile].size

          $log.debug("saving #{name}", :data=>h)
          super(h.inspect)
        end
      end
      # GETTER
      define_method name.to_s do |*args|
        eval(super(*args).to_s)
      end
    end
    
  end
  
  module InstanceMethods  
    
    # ===========
    # = Helpers =
    # ===========
  
    def upload_local_root; self.class.upload_local_root; end
    def upload_public_root; self.class.upload_public_root; end
    def upload_default_document; self.class.upload_default_document; end
  
    # path to the final directory containing files
    def local_upload_files_dir
      "#{upload_local_root}/#{self.class.to_s}/#{self.id || 'tmp'}"
    end

    # path to the final directory containing files
    def public_upload_files_dir
      "#{upload_public_root}/#{self.class.to_s}/#{self.id || 'tmp'}"
    end
    
    def uploaded?(col_name)
      __send__(col_name) != nil
    end
    
    # path to a file; if fn not specified, return the original file
    def upload_local_path(col_name, fn=nil)
      raise "not uploaded" unless uploaded?(col_name)
      if ! fn
        fn = ext_of_upload(col_name)
      end
      "#{local_upload_files_dir()}/#{col_name}.#{fn}"
    end
    
    # path to a file; if fn not specified, return the original file
    def upload_public_path(col_name, fn=nil)
      raise "not uploaded" unless uploaded?(col_name)
      if ! fn
        fn = ext_of_upload(col_name)
      end
      "#{public_upload_files_dir()}/#{col_name}.#{fn}"
    end
      
    # determine extension of the original file
    def ext_of_upload(col_name)
      raise "not uploaded" unless uploaded?(col_name)
      if up = self.send(col_name)
        if up[:name] =~ /\.([\w\d]+)$/
          return $1.gsub(/jpg/,'jpeg')
        else
          if type = up[:type]
            return type.split('/')[1].to_s.gsub(/jpg/,'jpeg')
          end
        end
      end
      raise "ext of #{col_name} can not be determined"
    end
    
    def image?(col_name)
      %w(jpg jpeg gif png).include?(ext_of_upload(col_name))
    end
              
    # to create named pictures on the fly
    def img_url(col_name, style=:default)
      style_proc, fname, ext, path = img_path_components(col_name, style)

      if ! File.exists?(path)
        $log.debug "upload: creating: #{path}"
        image_magick(col_name, fname, &style_proc)
      end
      
      upload_public_path(col_name, fname)
    end
    
    def img(col_name, style=:default, opts={})
      title = get_upload_title(col_name)
      "<img src='#{img_url(col_name, style)}' alt='#{CGI::escapeHTML(title)}' class='#{opts[:class]}'/>"
    end
    
    def identify_img(col_name, style=:default)
      style_proc, fname, ext, path = img_path_components(col_name, style)
      identify(path)
    end    
    
    # create a symlink to the original with title in it's url and keep the extension
    def orig_url(col_name)
      raise "not uploaded" unless uploaded?(col_name)
      
      title = get_upload_title(col_name)
      ascii = mkfname(title)
      
      fname = "#{ascii}.#{ext_of_upload(col_name)}"
      
      orig_path = upload_local_path(col_name)
      sympath   = upload_local_path(col_name, fname) 
          
      if ! File.exists?(sympath)
        File.symlink(File.basename(orig_path), sympath)
      end

      upload_public_path(col_name, fname)
    end
      
    # =========
    # = Hooks =
    # =========
  
    def after_save
      super rescue nil
      unless @tempfile_path.nil?        
        if @tempfile_path.empty?
          raise "upload/StorageFilesystem: got empty tempfile path; is the form enctype multipart/form-data?"          
        end
        $log.debug "upload/StorageFilesystem: going to store the tempfile"
        upload_dir = local_upload_files_dir()
        D::mkdir(upload_dir) unless F::exist?(upload_dir)
        @tempfile_path.each do |k,v|
          destroy_files_for(k) # Destroy previously saved files
          path = upload_local_path(k)
          FU.move(v, path) # Save the new one
          FU.chmod(0777, path)
          after_upload(k)
        end
        # Reset in case we access two times the entry in the same session
        # Like setting an attachment and destroying it in a row
        # Dummy ex:    Model.create(:img => file).update(:img => nil)
        @tempfile_path = nil
      end
    end
    
    def after_upload(col_name)
      # override me to process the attachment after upload
    end
  
    def destroy_files_for(col_name)
      D["#{local_upload_files_dir}/#{col_name}.*"].each {|f| FU.rm(f) }
    end
    alias destroy_file_for destroy_files_for
  
    def after_destroy
      super rescue nil
      dir = local_upload_files_dir()
      FU.rm_rf(dir) if F.exists?(dir)
    end
  
    # ===============
    # = ImageMagick =
    # ===============
  
    def convert(col_name, convert_steps="", style=nil)
      src  = upload_local_path(col_name, nil)
      dest = upload_local_path(col_name, style)
      cmd_full    = "convert \"#{src}\" #{convert_steps} \"#{dest}\""      # all frames (i.e. animated gifs)
      cmd_first   = "convert \"#{src}[0]\" #{convert_steps} \"#{dest}\""   # only first frame
      cmd_default = "convert \"#{upload_default_document}\" #{convert_steps} \"#{dest}\""
      if image?(col_name)
        system(cmd_full)  # animated gifs, etc.
        if ! File.exists?(dest) # maybe the animated gif can not be converted using full into jpg, try only first frame
          system(cmd_first)
        end
      else
        system(cmd_first) # pdf
      end
      if ! File.exists?(dest)
        system(cmd_default)
        $log.error "can't convert #{src}, default document used and #{dest}.error file created"
        File.open(dest+'.error','w+')
      end
    end

    private
    
    def identify(path)
      if File.exists?(path+'.identify')
        return YAML::load_file(path+'.identify')
      end
      
      h = {}
      if info = `identify \"#{path}\"`
        if info.strip.empty?
          $log.error "empty response from 'identify #{path}'"
        else
          ary = info.split(/\n/).first.split(/\s+/)  # next lines are frames of animated gifs, pdfs, etc.
          if ary[2].to_s =~ /(\d+)x(\d+)/  # is image
            h[:width], h[:height] = $1.to_i, $2.to_i
            h[:type] = "image/#{ary[1].downcase}"
            
            File.open(path+'.identify', 'w+') do |f| 
              f.write(h.to_yaml)
            end
          else
            $log.error "can't parse result of 'identify #{path}'", :info=>info
          end
        end
      end
      h
    end
        
    def get_upload_title(col_name)
      raise "upload: '#{col_name}' is not defined as upload column in the #{self.class.name}" unless self.class.upload_reflection.has_key?(col_name)
      title_col  = self.class.upload_reflection[col_name][:filename_from] ||= :title
      raise "upload: no filename_from=:#{title_col} defined in #{self}" unless self.respond_to?(title_col)
      title = self.send(title_col)
      title
    end
    
    def mkfname(str)
      str = ::Iconv.new('ascii//translit', 'utf-8').iconv(self.title.strip)
      str.gsub(/\s+/,'-').gsub(/[^\da-zA-Z0-9]+/,'-').gsub(/-+/,'-').downcase
    end   
    
    def img_path_components(col_name, style=:default)
      raise "not uploaded" unless uploaded?(col_name)
      
      title = get_upload_title(col_name)
      ascii = mkfname(title)
      
      style_proc, ext = self.class.upload_reflection[col_name][style]
      raise "no Proc defined for style=#{style}, got #{style_proc.class.name}" unless style_proc.kind_of?(Proc)
      if !ext  # no ext defined, use mime type
        ext = ext_of_upload(col_name)
      end
      if !ext
        raise "no ext defined for style=#{style}, no mime type info" 
      end
      
      fname = "#{ascii}.#{style}.#{ext}"      
      
      [style_proc, fname, ext, upload_local_path(col_name, fname)]
    end    
    
    # image magick convertors
    
    def image_magick(col_name, style=nil, &block)
      @image_magick_strings = []
      instance_eval &block
      convert_string = @image_magick_strings.join(' ')
      convert(col_name, convert_string, style)
      @image_magick_strings = nil
      convert_string
    end

    def im_write(s)
      @image_magick_strings << s
    end
    # when converting transparent png to jpg, it defaults to black background; this is a workaround
    def im_background(color)
      @image_magick_strings << "-background #{color} -alpha remove" 
    end
    def im_resize_only(width, height)  # animated gifs can't be resized with -gravity options etc.
      @image_magick_strings << "-resize '#{width}x#{height}'"
    end
    def im_resize(width, height, geometry_option=nil, gravity=nil)
      if width.nil? || height.nil?
        @image_magick_strings << "-resize '#{width}x#{height}#{geometry_option}'"
      else
        @image_magick_strings << "-resize '#{width}x#{height}#{geometry_option}' -gravity #{gravity || 'center'} -extent #{width}x#{height}"
      end
    end
    def im_crop(width, height, x, y)
      @image_magick_strings <<  "-crop #{width}x#{height}+#{x}+#{y} +repage"
    end
    def im_negate
      @image_magick_strings << '-negate'
    end
    
  end
  
end
