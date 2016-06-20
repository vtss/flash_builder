require 'json'
require 'erb'

class ResultNode
  attr_accessor :name, :status, :meta, :siblings
  def initialize(name, status = "", meta = nil)
    @name = name
    @status = status
    @meta = meta
    @siblings = []
  end
  def addSibling(node)
    @siblings << node
  end
  def reCalc
    if @siblings.length == 0
      return @status
    end
    sub_status = []
    @siblings.each do |s|
      sub_status << s.reCalc()
    end
    # Finde unique values
    sub_status.uniq!
    @status = (sub_status.length == 1 ? sub_status[0] : "Failed")
    return @status
  end
  # General conversion
  def to_hash
    n = { 'name' => @name, 'status' => @status, 'meta' => @meta, 'siblings' => [] }
    @siblings.each do |s|
      n['siblings'] << s.to_hash()
    end
    n
  end
  def self.from_hash(h)
    h.each do |i,n|
      return nil if !(i =~ /name|status|meta|siblings/i)
    end
    n = ResultNode.new(h['name'], h['status'], h['meta'])
    h['siblings'].each do |s|
      n.addSibling(ResultNode.from_hash(s))
    end
    n
  end
  # JSON support
  def to_json(state = nil)
    to_hash().to_json
  end
  # File IO
  def self.from_file(f)
    from_hash(JSON.parse(File.read(f)))
  end
  def to_file(f)
    reCalc()
    File.write(f, JSON.dump(to_hash))
  end
  # Debug
  def dump(p = '>')
    %W{name status}.each do |i,n|
      puts "#{p} @#{i}: #{instance_variable_get('@'+i)}"
    end
    puts p + " metadata: " + JSON.dump(@meta) if !@meta.nil?
    @siblings.each do |s|
      s.dump(p+'>')
    end
    puts p+"---"
  end
  # ERB/render formatting
  def render(template)
    ERB.new(template).result(binding)
  end
  def render_xml()
    render(<<END
<% def draw_node(node, _erbout) %>
<node name="<%= node.name %>" status="<%= node.status %>" >
 <% if node.meta %>
 <metadata>
   <% node.meta.each do |k,v| %>
   <meta key="<%= k %>" value="<%= v %>"/>
   <% end %>
 </metadata>
 <% end %>
 <% if node.siblings.length > 0 %>
 <siblings>
   <% for i in node.siblings %>
   <% draw_node(i, _erbout) %>
   <% end %>
 </siblings>
 <% end %>
</node>
 <% end %>
<%= draw_node(self, "") %>}
END
          )
  end
end
