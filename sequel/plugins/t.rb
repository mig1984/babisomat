module ::Sequel::Plugins::T
  
  module InstanceMethods

    def t(x)
      if File.exists?("locales/#{self.class.name}.yaml")
        # must use @@locales otherwise locales will stay cached in User for the entrire login time
        @@locales ||= {}
        @@locales[self.class.name] ||= YAML::load_file("locales/#{self.class.name}.yaml")
        @@locales[self.class.name][x.to_s] || "NO-TRANSLATION #{x}"
      else
        x.to_s
      end
    end
     
  end
  
end
