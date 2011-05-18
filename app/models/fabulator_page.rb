class FabulatorPage < Page
  attr_accessor :inner_content, :compilation_errors

  description %{
    A Fabulator page allows you to create a simple, interactive
    web application that manages data in RDF models defined in the
    Fabulator > RDF Models tab of the administrative area.
  }
  # need a reasonable name for the XML part
  XML_PART_NAME = 'extended'

  after_find :check_compile
  attr_accessor :resource_ln, :c_state_machine

  # create tags to access filtered data in page display
  # might also create tags for form fields, etc., so it's easy to
  # create a form and fill in data

  def cache?
    false
  end

  def check_compile
    self[:compiled_xml] = nil
    @compiled_xml = nil
    @compilation_errors = nil
    
    content = self.part(XML_PART_NAME)
    return if content.nil?
    content = content.content
    return if content.blank?
    
    doc = nil
    begin
      doc = Nokogiri::XML::Document.parse(self.part(XML_PART_NAME).content, nil, nil,
      Nokogiri::XML::ParseOptions::STRICT|Nokogiri::XML::ParseOptions::PEDANTIC|Nokogiri::XML::ParseOptions::NONET)
    rescue => e
      @compilation_errors = e.message + " near line #{e.line} column #{e.column}"
    end
    return if doc.nil?
    begin
      self.state_machine
    rescue => e
      # note errors somewhere that can be made visible and raise an exception
      @compilation_errors = e
      raise "Unable to compile application."
    end
  end
  
  def find_by_url(url, live = true, clean = false)
    p = super
    return p if !p.nil? && !p.is_a?(FileNotFoundPage)

    url = clean_url(url) if clean
    if url =~ %r{^#{ self.url }([-_0-9a-zA-Z]+)/?$}
      self.resource_ln = $1
      return self
    else
      return p
    end
  end

  def url
    u = super
    if !self.resource_ln.nil?
      u = u + '/' + self.resource_ln
    end
    u
  end

  def state_machine
    return @state_machine unless @state_machine.nil?

    FabulatorLibrary.all.each do |library|
      if library.compiled_xml.is_a?(Fabulator::Lib::Lib)
        library.compiled_xml.register_library
      end
    end

    compiler = Fabulator::Compiler.new
    part = self.part(XML_PART_NAME)
    @state_machine = compiler.compile(part.content)

    return @state_machine

    if self.compiled_xml.nil? || self.compiled_xml == ''
      self.c_state_machine = nil
    else
      self.c_state_machine = (YAML::load(self.compiled_xml) rescue nil) unless self.c_state_machine
    end
    self.c_state_machine
  end

  def fabulator_context
    if @roots.nil?
      @roots = { }
    end

    if @roots['data'].nil?
      @roots['data'] = Fabulator::Expr::Node.new('data', @roots, nil, [])
      ctx = Fabulator::Expr::Context.new
      ctx.root = @roots['data']
      ctx.traverse_path(['resource'], true).first.value = self.resource_ln if self.resource_ln
      self.state_machine.init_context(ctx)
    end
    @roots['data']
  end

  def fabulator_context=(c)
    fc = self.fabulator_context
    @roots = { } if @roots.nil?
    @roots['data'] = c
  end

  def headers
    if @resetting_context
      {
        :location => self.url,
      }
    elsif @redirecting
      {
        :location => @redirecting,
      }
    else
      { }
    end
  end

  def response_code
    @resetting_context ? 302 : ( @redirecting ? 304 : 200 )
  end

  def render_snippet(p)
    if p.name != XML_PART_NAME
      FabulatorFilter.set_page(self)
      r = super
      FabulatorFilter.reset_page
      r
    else
      FabulatorLibrary.all.each do |library|
        if library.compiled_xml.is_a?(Fabulator::Lib::Lib)
          library.compiled_xml.register_library
        end
      end

      sm = self.state_machine
      return '' if sm.nil?

      # run state machine if POST
      context = FabulatorContext.find_by_page(self)
      @resetting_context = false

      if request.method == :get && 
         params[:reset_context]
        if !context.new_record?
          context.destroy
        end
        # redirect without the reset_context param?
        @response.redirect(url,302)
        @resetting_context = true
        return
      end

      begin
        sm.context = YAML::load(context.context)
        if sm.context.empty?
          sm.init_context(self.fabulator_context)
        end
        #sm.context.merge!(self.resource_ln, ['resource'] ) if self.resource_ln
        if request.method == :post
          sm.run(params)
          # save context
          @sm_missing_args = sm.missing_params
          @sm_errors       = sm.errors
          context.context = YAML::dump(sm.context)
          context.save
        end
        # save statemachine state
        # display resulting view
      rescue Fabulator::FabulatorRequireAuth => e
        @redirecting = e.to_s
      rescue => e
        return "<p>#{e.to_s}</p><pre>" + e.backtrace.join("\n") + "</pre>"
      end
      return '' if @redirecting
      if sm.state != XML_PART_NAME
        return self.render_part(sm.state)
      else
        return 'Error: Fabulator application is not in a displayable state.'
      end
    end
  end

  def missing_args
    @sm_missing_args
  end

  tag 'fabulator' do |tag|
    tag.locals.fabulator_context = tag.locals.page.fabulator_context
    tag.expand
  end

  desc %{
    Formats the enclosed logical form markup, adds default values,
    existing values, and marks errors or warnings and required fields.
  }
  tag 'form' do |tag|
    # get xml markup of form and transform it via xslt while adding
    # default values and such
    # wrap the whole thing in a form tag to post back to this page
    xml = tag.expand
    return '' if xml.blank?

    text_parser = Fabulator::Template::Parser.new

    c = get_fabulator_context(tag)
    root = nil

    page = tag.locals.page

    form_base = tag.attr['base']
    if form_base.nil? || form_base == ''
      root = c
      form_base = c.root.path.gsub(/^.*::/, '').gsub('/', '.').gsub(/^\.+/, '')
    else
      root = c.nil? ? nil : c.with_root(c.eval_expression('/' + form_base.gsub('.', '/')).first)
      root = c if !c.nil? && root.root.nil?
    end
    root = c

    ## TODO: we only want to transform to HTML if we are not using
    ## the Fabulator filter

    xml = "<form xmlns='http://dh.tamu.edu/ns/fabulator/1.0#' id='#{form_base}'>" + xml + %{</form>}
    doc = text_parser.parse(c, xml)

    # add default values
    return doc if doc.is_a?(String)

    doc.add_default_values(root)
    doc.add_missing_values(page.statemachine.missing_params)
    doc.add_errors(page.statemachine.errors)

    doc.to_html
  end

  desc %{
    Iterates through a set of data nodes.

    *Usage:*

    <pre><code><r:for-each select="./foo">...</r:for-each></code></pre>
  }
  tag 'for-each' do |tag|
    selection = tag.attr['select']
    c = get_fabulator_context(tag)
    ns = get_fabulator_ns(tag)
    items = c.nil? ? [] : c.eval_expression(selection)
    sort_by = tag.attr['sort']
    sort_dir = tag.attr['order'] || 'asc'

    as = tag.attr['as']

    if !sort_by.nil? && sort_by != ''
      parser = Fabulator::Expr::Parser.new
      sort_by_f = parser.parse(sort_by, c)
      items = items.sort_by { |i| c.with_root(i).eval_expression(sort_by_f).first.value }
      if sort_dir == 'desc'
        items.reverse!
      end
    end
    res = ''
    items.each do |i|
      next if i.empty?
      tag.locals.fabulator_context = c.with_root(i)
      if !as.blank?
        tag.locals.fabulator_context.set_var(as, i)
      end
      res = res + tag.expand
    end
    res
  end

  desc %{
    Selects the value and returns it in HTML.

    *Usage:*

    <pre><code><r:value-of select="./foo" [raw="false"] /></code></pre>
  }
  tag 'value-of' do |tag|
    selection = tag.attr['select']
    c = get_fabulator_context(tag)
    items = c.nil? ? [] : c.eval_expression(selection)
    if tag.attr['raw'] && ['true', 'yes'].include?(tag.attr['raw'])
      items.collect{|i| c.with_root(i).to([Fabulator::FAB_NS, 'string']).root.value }.join('')
    else
      items.collect{|i| c.with_root(i).to([Fabulator::FAB_NS, 'html']).root.value }.join('')
    end
  end

  desc %{
    Chooses the first test which returns content.  Otherwise,
    uses the 'otherwise' tag.
  }
  tag 'choose' do |tag|
    @chosen ||= [ ]
    @chosen.unshift false
    ret = tag.expand
    @chosen.shift
    ret
  end

  desc %{
    Renders the enclosed content if the test passes.
  }
  tag 'choose:when' do |tag|
    return '' if @chosen.first
    selection = tag.attr['test']
    c = get_fabulator_context(tag)
    items = c.nil? ? [] : c.eval_expression(selection)
    if items.is_a?(Array)
      if items.empty? || !items[0].value
        return ''
      else
        @chosen[0] = true
        return tag.expand
      end
    elsif items
      @chosen[0] = true
      return tag.expand
    end
    return ''
  end

  desc %{
    Renders the enclosed content.
  }
  tag 'choose:otherwise' do |tag|
    return '' if @chosen.first
    tag.expand
  end

  desc %{
    Renders the inherited view.
  }
  tag 'inner' do |tag|
    @inner_content.nil? ? '' : @inner_content
  end

  desc %{
    Renders the parent view providing the child view as an augmentation.
  }
  tag 'augment' do |tag|
    parent_page = self.state_machine.isa
    inner = tag.expand
    return inner if parent_page.nil?
    parent_page.inner_content = inner
    parent_page.render_part(self.state_machine.state)
  end

private

  def get_fabulator_ns(tag)
    c = tag.locals.page
    if c.nil?
      c = tag.globals.page
    end
    ret = (c.state_machine.namespaces rescue { })
    ret
  end

  def get_fabulator_context(tag)
    c = tag.locals.fabulator_context
    if c.nil? 
      c = tag.locals.page.state_machine.fabulator_context
      if c.nil?
        c = tag.globals.page.state_machine.fabulator_context
      end
    end
    # TODO: move serialization back into the model
    if c.is_a?(String)
      c = YAML::load(c)
    end
    if c.is_a?(Hash)
      c = c[:data]
    end
    return c
  end
end
