module TinyMCEFilterShared
  
  # all links to www.novinky.cz, will be replaced in layout, unless already attribute set
  # (otherwise links to novinky in bodies won't work)
  def novinky_links()
    @str.gsub!(/<a (.*?)>/m) do |m|
      x = $1
      if x =~ /www\.novinky\.cz/
        "<a #{x} already='1'>"
      else
        "<a #{x}>"
      end
    end
    self
  end

  def quotes()
    @str.gsub!(/<p>(.*?)<\/p>/m) do 
      insidep = $1
      opened = false      
      insidep.gsub!(/&quot;(?!([^<]+)?>)/mi) do
        opened=!opened
        if opened
          "&bdquo;"
        else
          "&ldquo;"
        end
      end
      '<p>' << insidep << '</p>'
    end
    self
  end
  
end
