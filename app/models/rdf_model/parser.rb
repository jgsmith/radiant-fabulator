class RdfModel::Parser
  RDF_NS='http://www.w3.org/1999/02/22-rdf-syntax-ns#'
  RDFS_NS='http://www.w3.org/2000/01/rdf-schema#'
  XML_NS='http://www.w3.org/XML/1998/namespace'

  def parse(xml, base=nil)
    @baseURI = xml.attributes.get_attribute_ns(XML_NS, 'base')
    if @baseURI.nil?
      @baseURI = base 
    elsif baseURI =~ /^(.*)#(.*)$/
      @baseURI = $1
    end

    Rails.logger.info(">>>>>>>>>>> begin parse of #{xml.namespaces.namespace.href}#{xml.name}")
    if xml.namespaces.namespace.href == RDF_NS && xml.name == 'RDF' 
      xml.each_element do |e|
        self.xml_node(e)
      end
    end
    Rails.logger.info(">>>>>>>>>>> end parse of #{xml.name}")
  end

  def xml_node(e)
    Rails.logger.info(">>>>>>>>>>>>>>> begin node #{e.name}")
    if !(e.namespaces.namespace.href == RDF_NS && e.name == 'Description')
      bnode = RdfResource.create_bnode
      e.each_attr do |attr|
        next if attr.namespace.href == RDF_NS
        Rails.logger.info("#{bnode} #{attr.namespace.href+attr.name}, #{attr.value}")
        yield [ bnode, RdfResource(attr.namespace.href + attr.name), RdfLiteral.build(attr.value) ]
      end
      s = e.attributes.get_attribute_ns(RDF_NS, 'about')
      if !s.nil?
        s = RdfResource.from_uri(self.expand(e, s.value))
      else
        s = bnode
      end
      p = RdfResource.from_uri(RDFS_NS, 'type')
      o = RdfResource.from_uri(e.namespaces.namespace.href + e.name)
      Rails.logger.info("#{s} #{p} #{o}")
      yield [ s, p, o ]
    else
      e.each_attr do |attr|
        next if attr.namespace.href == RDF_NS
        s = RdfResource.from_uri(@baseURI + '#' + e.parent_element.attributes.get_attribute_ns(RDF_NS, 'ID').value)
        p = RdfResource.from_uri(attr.namespace.href + attr.name)
        o = RdfLiteral.build(attr.value)
      Rails.logger.info("#{s} #{p} #{o}")
        yield [ s, p, o ]
      end
    end
    e.each_element do |child|
      self.xml_arc(child, blk)
    end
    Rails.logger.info(">>>>>>>>>>>>>>> end node")
  end

  def xml_arc(e, &blk)
    Rails.logger.info(">>>>>>>>>>>>>>>>>>> begin arc")
    subject = e.parent.attributes.get_attribute_ns(RDF_NS, 'about').value rescue nil
    if subject.nil?
      subject = e.parent.attributes.get_attribute_ns(RDF_NS, 'ID').value rescue nil
      if !subject.nil?
        subject = @baseURI + '#' + subject
      else
        subject = RdfResource.bnode
      end
    end
    if e.namespaces.namespace.href == RDF_NS && e.local_name == 'li'
      predicate = RDF_NS + '_'
    end
    Rails.logger.info(">>>>>>>>>>>>>>>>>>> begin arc")
  end

  # Resolve relative references to absolute form
  def expand(e, there)
    if there =~ /^(.*)#(.*)$/
      rest = $1
      hashFragment = $2
    else
      rest = there
      hashFragment = ''
    end
    if rest.empty?
      return @baseURI + hashFragment
    end
    if r =~ /^(.*):(.*)$/
      scheme = $1
      rest2 = $2
    else
      scheme = ''
      rest2 = r
    end
    if scheme =~ /^[a-zA-Z][-a-zA-Z.0-9]*$/
      return there
    end
    if @baseURI =~ /^([a-zA-Z][-a-zA-Z.0-9]+):(.*)$/
      baseScheme = $1
      baseRest = $2
    else
      baseScheme = ''
      baseRest = base
    end
    if rest2 =~ /^\/\//
      return baseScheme + ':' + rest2 + hashFragment
    end
    # ... need to finish this
  end

  def split_scheme(r)
    if r =~ /^([a-zA-Z][-a-zA-Z.0-9]*):/
      return $1
    else
      return ''
    end
  end
end
