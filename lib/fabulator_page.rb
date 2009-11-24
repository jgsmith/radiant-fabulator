class FabulatorPage < Page
  # need a reasonable name for the XML part
  XML_PART_NAME = 'extended'

  after_save :set_defaults

  # create tags to access filtered data in page display
  # might also create tags for form fields, etc., so it's easy to
  # create a form and fill in data

  def render_snippet(p)
    if p.name != XML_PART_NAME
      super
    else
      sm = YAML::load(self.compiled_xml)

      # run state machine if POST
      Rails.logger.info("Fabulator page request method: #{request.method}")
      if request.method.to_s.downcase == 'post'
        sm.run(params)
        # save context
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

  tag 'fabulator' do |tag|
    tag.expand
  end

  desc %{
    Formats the enclosed logical form markup, adds default values,
    existing values, and marks errors or warnings and required fields.
  }
  tag 'fabulator:form' do |tag|
    # get xml markup of form and transform it via xslt while adding
    # default values and such
    # wrap the whole thing in a form tag to post back to this page
    xml = tag.expand
    return '' if xml.blank?

    xml = %{<view><form>} + xml + %{</form></view>}
    doc = REXML::Document.new xml
    # add errors and other info to doc
    # then return the result of applying the xslt/form.xslt
    xslt = XML::XSLT.new()
    xslt_file = RAILS_ROOT + '/vendor/extensions/fabulator/xslt/form.xsl'
    Rails.logger.info("xslt file: #{xslt_file}")
    xslt.parameters = { }
    xslt.xml = doc
    xslt.xsl = REXML::Document.new File.open(xslt_file)
    xslt.serve()
  end

private

  def set_defaults
    # create a part for each state in the document
    # 'body' is a description/special
    # 'sidebar' is reserved

    return if @in_set_defaults
    @in_set_defaults = true

    # compile statemachine into a set of Ruby objects and save
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
