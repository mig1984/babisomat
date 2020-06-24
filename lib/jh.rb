require 'cgi'

module JH

  # escape javascript
  def j(x)
    x.to_s.gsub(/"/,'\\"').gsub(/'/,"\\\\'")
  end
  
  def h(str)
    CGI::escapeHTML(str.to_s)
  end

end
