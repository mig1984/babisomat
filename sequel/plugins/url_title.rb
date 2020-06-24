require 'iconv'

# to work:
#
# export LANG=en_US.UTF-8
# export LANGUAGE=en_US:en

a = "ňéěžščříáýúůóďťÝŽŠČŘĚÍŇÓĎŤ"
b = 'neezscriayuuodtYZSCREINODT'
res = ::Iconv.new('ascii//translit', 'utf-8').iconv(a)
raise "iconv is not producing expected output; '#{res}' != '#{b}'" if res != b

module ::Sequel::Plugins::UrlTitle
  
  module InstanceMethods

    def url_title(title=self.title)
      str = ::Iconv.new('ascii//translit', 'utf-8').iconv(title)
      str.gsub(/\s+/,'-').gsub(/[^\da-zA-Z]+/,'-').gsub(/-+/,'-').downcase
    end

  end
  
end
