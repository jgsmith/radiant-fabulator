class FabulatorPage < Page
  description %{
    A Fabulator page allows you to create a simple, interactive
    web application that manages data in RDF models defined in the
    Fabulator > RDF Models tab of the administrative area.
  }
  # need a reasonable name for the XML part
  XML_PART_NAME = 'extended'

  after_save :set_defaults
  attr_accessor :resource_ln

  # create tags to access filtered data in page display
  # might also create tags for form fields, etc., so it's easy to
  # create a form and fill in data

  def cache?
    false
  end

  def find_by_url(url, live = true, clean = false)
    Rails.logger.info("find_by_url(#{url}, #{live}, #{clean})")
    Rails.logger.info("invoking super")
    p = super
    Rails.logger.info("returning from super")
    Rails.logger.info("Found #{p}")
    return p if !p.nil? && !p.is_a?(FileNotFoundPage)
    Rails.logger.info("Seeing if we have a resource")

    url = clean_url(url) if clean
    Rails.logger.info("Our url: #{self.url}")
    Rails.logger.info("Target url: #{url}")
    if url =~ %r{^#{ self.url }([-_0-9a-zA-Z]+)/?$}
      Rails.logger.info("resource: #{$1}")
      self.resource_ln = $1
      return self
    else
      return p
    end
  end

  def url
    Rails.logger.info("Getting url")
    u = super
    if !self.resource_ln.nil?
      u = u + '/' + self.resource_ln
    end
    Rails.logger.info("Returning '#{u}' as url")
    u
  end

  def state_machine
    @state_machine ||= YAML::load(self.compiled_xml)
  end

  def fabulator_context
    if @roots.nil?
      @roots = { }
    end

    if @roots['locals'].nil?
      @roots['locals'] = Fabulator::XSM::Context.new('locals', @roots, nil, [])
      @roots['locals'].traverse_path(['resource'], true).first.value = self.resource_ln if self.resource_ln
      self.state_machine.init_context(@roots['locals'])
    end
    @roots['locals']
  end

  def fabulator_context=(c)
    fc = self.fabulator_context
    @roots = { } if @roots.nil?
    @roots['locals'] = c
  end

  def headers
    if @resetting_context
      {
        :location => self.url,
      }
    else
      { }
    end
  end

  def response_code
    @resetting_context ? 302 : 200
  end

  def render_snippet(p)
    if p.name != XML_PART_NAME
      super
    else
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

      sm.context = context.context
      if sm.context.empty?
        sm.init_context(self.fabulator_context)
      end
      #sm.context.merge!(self.resource_ln, ['resource'] ) if self.resource_ln
      if request.method == :post
        sm.run(params)
        # save context
        @sm_missing_args = sm.missing_params
        @sm_errors       = sm.errors
        context.update_attribute(:context, sm.context.context)
      end
      # save statemachine state
      # display resulting view
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

    c = get_fabulator_context(tag)

    missing_args = tag.locals.page.missing_args

    form_base = tag.attr['base']
    if form_base.nil?
      root = c
      form_base = c.path.gsub(/^.*::/, '').gsub('/', '.').gsub(/^\.+/, '')
    else
      root = c.nil? ? nil : c.eval_expression('/' + form_base.gsub('.', '/')).first
    end
    root = c

    xml = %{<view><form>} + xml + %{</form></view>}
    doc = REXML::Document.new xml
    # add errors and other info to doc
    form_el = REXML::XPath.first(doc,'/view/form')
    form_el.add_attribute('id', form_base)

    # add default values
    # borrowed heavily from http://cpansearch.perl.org/src/JSMITH/Gestinanna-0.02/lib/Gestinanna/ContentProvider/XSM.pm

    REXML::XPath.each(doc.root, %{
      //text
      | //textline
      | //textbox
      | //editbox
      | //file
      | //password
      | //selection
      | //grid
    }) do |el|
      own_id = el.attribute('id')
      next if own_id.nil? || own_id.to_s == ''

      default = 0
      is_grid = false
      if el.local_name == 'grid'
        default = REXML::XPath.match(el, './default | ./row/default | ./column/default')
        is_grid = true
      else
        default = REXML::XPath.match(el, './default')
      end

      #missing = el.attribute('missing')

      ancestors = REXML::XPath.match(el, %{
        ancestor::option[@id != '']
        | ancestor::group[@id != '']
        | ancestor::form[@id != '']
        | ancestor::container[@id != '']
      })
      ids = ancestors.collect{|a| a.attribute('id')}.select{|a| !a.nil? }
      ids << own_id
      id = ids.collect{|i| i.to_s}.join('.')
      ids = id.split('.')
      if !root.nil? && (default.is_a?(Array) && default.empty? || !default)
        # create a new node 'default'
        l = root.traverse_path(ids)
        if !l.nil? && !l.empty?
          if is_grid
            count = (el.attribute('count').to_s rescue '')
            how_many = 'multiple'
            direction = 'both'
            if count =~ %r{^(multiple|single)(-by-(row|column))?$}
              how_many = $1
              direction = $3 || 'both'
            end
            if direction == 'both'
              l.collect{|ll| ll.value }.each do |v|
                default = el.add_element('default')
                default.add_text(v)
              end
            elsif direction == 'row' || direction == 'column'
              REXML::XPath.each(el, "./#{direction}").each do |div|
                id = (div.attribute('id').to_s rescue '')
                next if id == ''
                l.collect{|c| c.traverse_path(id)}.flatten.collect{|c| c.value }. each do |v|
                  default = div.add_element('default')
                  default.add_text(v)
                end
              end
            end
          else
            l.collect{|ll| ll.value }.each do |v|
              default = el.add_element('default')
              default.add_text(v)
            end
          end
        end
      end
      # now handle missing info for el

      if !missing_args.nil? && missing_args.include?(id)
        el.add_attribute('missing', '1')
      end
    end

    # then return the result of applying the xslt/form.xslt
    xslt = XML::XSLT.new()
    xslt_file = RAILS_ROOT + '/vendor/extensions/fabulator/xslt/form.xsl'
    xslt.parameters = { }
    xslt.xml = doc
    xslt.xsl = REXML::Document.new File.open(xslt_file)
    xslt.serve()
  end

  desc %{
    Iterates through a set of data nodes.

    *Usage:*

    <pre><code><r:for-each select="./foo">...</r:for-each></code></pre>
  }
  tag 'for-each' do |tag|
    selection = tag.attr['select']
    c = get_fabulator_context(tag)
    Rails.logger.info("context: #{YAML::dump(c)}")
    Rails.logger.info("for-each: #{selection} from #{c}")
    items = c.nil? ? [] : c.eval_expression(selection)
    res = ''
    Rails.logger.info("Found #{items.size} items for for-each")
    items.each do |i|
      next if i.empty?
      tag.locals.fabulator_context = i
      res = res + tag.expand
    end
    res
  end

  desc %{
    Selects the value and returns it in HTML.
    TODO: allow escaping of HTML special characters

    *Usage:*

    <pre><code><r:value select="./foo" /></code></pre>
  }
  tag 'value' do |tag|
    selection = tag.attr['select']
    c = get_fabulator_context(tag)
    items = c.nil? ? [] : c.eval_expression(selection)
    items.collect{|i| i.value }.join('')
  end

  desc %{
    Chooses the first test which returns content.  Otherwise,
    uses the 'otherwise' tag.
  }
  tag 'choose' do |tag|
    tag.locals.chosen = false
    tag.expand
  end

  desc %{
    Renders the enclosed content if the test passes.
  }
  tag 'choose:when' do |tag|
    return '' unless tag.locals.chosen
    selection = tag.attr['test']
    c = get_fabulator_context(tag)
    items = c.nil? ? [] : c.eval_expression(selection)
    if items.is_a?(Array)
      if items.empty?
        return ''
      else
        tag.locals.chosen = true
        return tag.expand
      end
    elsif items
      tag.locals.chosen = true
      return tag.expand
    end
    return ''
  end

  desc %{
    Renders the enclosed content.
  }
  tag 'choose:otherwise' do |tag|
    return '' if tag.locals.chosen
    tag.expand
  end


private

  def get_fabulator_context(tag)
    c = tag.locals.fabulator_context
    if c.nil? 
      c = tag.locals.page.fabulator_context 
      if c.nil?
        c = tag.globals.page.fabulator_context
      end
    end
    if c.is_a?(Hash)
      c = c[:data]
    end
    return c
  end

  def set_defaults
    # create a part for each state in the document
    # 'body' is a description/special
    # 'sidebar' is reserved

    return if @in_set_defaults
    @in_set_defaults = true

    # compile statemachine into a set of Ruby objects and save
    xml_part = (part(XML_PART_NAME).content rescue '')
    if xml_part.nil? || xml_part == ''
      self.update_attribute(:compiled_xml, YAML::dump(nil))
      return
    end

    doc = LibXML::XML::Document.string part(XML_PART_NAME).content
    # apply any XSLT here
    # compile
    sm = Fabulator::StateMachine.new(doc, logger)
    logger.info(YAML::dump(sm))

    self.update_attribute(:compiled_xml, YAML::dump(sm))

    # not the most efficient, but we don't usually have hundreds of states
    sm.state_names.sort.each do |part_name|
      parts.create(:name => part_name, :content => %{
        <h1>View for State #{part_name}</h1>
      }) unless parts.any?{ |p| p.name == part_name }
    end

    @in_set_defaults = false
  end

end
