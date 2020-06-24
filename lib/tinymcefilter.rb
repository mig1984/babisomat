require 'rack/utils'
require 'nokogiri'

class TinyMCEFilter

  def initialize(str, opts={})
    @str = str.to_s.clone
    @opts = {}
    absolute_public()
    quots()
    shorts()
    self
  end
  
  # ../../../../public => /public
  private def absolute_public()
    @str.gsub!(/(\.\.\/)+public/, '/public')
    self
  end
  
  private def quots()
    @str.gsub!(/(>([^<]+?)<)/) do
      s = $2
      s.gsub!(/'/,'&#x27;')
      s.gsub!(/"/,'&quot;')
      '>'+s+'<'
    end
    self
  end

  private def shorts()
    @str.gsub!(/(\s([szkvaiou]|ve|od|do|za|na|po))\s/i, '\\1&nbsp;')
    self
  end
  
  # &nbsp; => ' '
  def unescape()
    @str = Nokogiri::HTML::DocumentFragment.parse(@str).to_s
    self
  end
  
  def strip_tags()
    @str.gsub!(/<[^>]+>/m,'')
    self
  end
  
  def strip_first_p()
    @str.gsub!(/^\s*<p>(.*?)<\/p>\s*$/m, '\\1')        
  end
  
  def strip_p()
    @str.gsub!(/<p>/,'')        
    @str.gsub!(/<\/p>/,'<br/>')
    self
  end
  
  def strip_a()
    @str.gsub!(/<a [^>]*?>|<\/a\s*>/m,'')
    self
  end
  
  def strip_empty_p()
    @str.gsub!(/<p(\s[^>]*?)?>(\s| |&nbsp;)*<\/p>/m,'')
    self
  end

  def strip_ending_br()
    @str.gsub!(/<br\s*\/>\s*$/,'')
    self
  end  
  
  def to_s()
    @str
  end
    
  def h(str)
    Rack::Utils.escape_html(str)
  end
  
end
