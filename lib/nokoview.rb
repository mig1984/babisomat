require 'nokogiri'

module NokogiriMethods

  def first
    raise "first: nothing found, expected at least one match" if length==0
    super
  end
  
  def last
    raise "last: nothing found, expected at least one match" if length==0
    super
  end
  
  def one
    raise "nothing found, expected one match" if length==0
    raise "found #{length}, expected one match" if length>1
    first
  end
  
  def many
    raise "nothing found, expected at least one match" if length==0
    self
  end
  
  def gsub_text!(rxp, s)
    cnt = 0
    traverse do |node|
      next unless node.is_a?(::Nokogiri::XML::Text)
      if node.content =~ rxp
        node.content = node.content.gsub(rxp, s)
        cnt+=1
      end
    end
    raise "#{rxp} not matched" if cnt==0
    cnt
  end
  
  def text_includes(txt, elm="*")
    xpath( %Q[ .//#{elm}[contains(text(), '#{txt}')] ])
  end

  def text_equals(txt, elm="*")
    xpath( %Q[ .//#{elm}[text()='#{txt}'] ])
  end

  # span_includes
  # h3_includes
  def method_missing(m, *args)
    if m.to_s=~/([^_]+)(_includes|_equals)/
      if $2=='_includes'
        text_includes(args.first, $1)
      else
        text_equals(args.first, $1)
      end
    else
      super(*args)
    end
  end

end

Nokogiri::XML::Node.send(:prepend, NokogiriMethods)
Nokogiri::XML::NodeSet.send(:prepend, NokogiriMethods)

#it does not override default first/last without doing this...
# class Nokogiri::XML::NodeSet
#   alias :orig_first :first
#   def first ; orig_first; end
#   alias :orig_last :last
#   def last  ; orig_last; end
# end

# class NokoWeb < NokoView
#
#   def layout(s)
#   end
#
#   def _homepage
#     xyz # will access parent.xyz (see method missing)
#   end
#
# end
#
# to set a different layout:
#    nv = NokoWeb.new(self)
#    nv.layout = :foo
#    puts nv.homepage
# to see a part (no layout):
#    nv = NokoWeb.new(self)
#    puts nv._homepage

class NokoView

  attr_accessor :layout

  def initialize(parent)
    @parent = parent
    @parent.instance_variables.each do |k|
      v = @parent.instance_eval { instance_variable_get(k) }
      instance_variable_set(k, v)
    end
  end

  def method_missing *args
    lay = @layout || :layout
    view = ('_' << args.first.to_s).to_sym
    if respond_to?(view)
      @view = args.first.to_s.to_sym
      body_contents = send(view, *args[1..-1])
      lay ? send(lay, body_contents) : body_contents
    else
      @parent.send(*args)
    end
  end
  
  # keep html entities untouched  
  def xhtml(x)
    doc = <<-HERE
      <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
      <html xmlns="http://www.w3.org/1999/xhtml">
      <head><meta charset="UTF-8" /></head><body>#{x}</body></html>
    HERE
    Nokogiri::XML(doc).css('body').children
  end
  
  # keep <script> contents untouched
  def html(x)
    doc = <<-HERE
      <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
      <html xmlns="http://www.w3.org/1999/xhtml">
      <head><meta charset="UTF-8" /></head><body>#{x}</body></html>
    HERE
    Nokogiri::HTML(doc).css('body').children
  end
  
  def parse(path)
    if ENV['ENVIRONMENT']=='development'
      Nokogiri::HTML.parse(File.open(path))
    else
      @noko_parsed ||= {}
      @noko_parsed[path] ||= Nokogiri::HTML.parse(File.open(path))
      @noko_parsed[path].dup
    end    
  end

  # override me; example
  def layout body_contents
    doc = parse("nokoviews/hk/layout.xml")
    # replace <body> in the layout with the body_contents
    body = doc.at_css('body')
    body.add_next_sibling n(body_contents).at('body')
    body.remove
    doc.at_css('title').content = @title
    doc.to_html
  end

  # override me; example
  def _index
    doc = parse("nokoviews/hk/index.xml")
    body = doc.at_css('body')
    @title ||= 'INDEX!'
    table = body.at_css('table')
    row = table.at_css('tr')
    orig_children = table.children
    5.times do |i|
      row = row.dup
      row.at_css('td:nth-child(1)').content = i.to_s
      row.at_css('td:nth-child(2)').content = 'XYZ'
      table << row
    end
    orig_children.remove
    body.to_html
  end

end
