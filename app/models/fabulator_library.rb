class FabulatorLibrary < ActiveRecord::Base
  validates_presence_of :name
  validates_uniqueness_of :name

  belongs_to :updated_by, :class_name => 'User'
  belongs_to :created_by, :class_name => 'User'

  serialize :compiled_xml

  before_save :compile_xml
  
  attr_accessor :compilation_errors

  def compile_xml
    lib = nil
    begin
      lib = self.compile_xml!
    rescue => e
      # add error
      Rails.logger.info("Error compiling library: #{e}")
    end
    self.compiled_xml = lib
  end
  
  def has_compile_errors?
    @compiled_xml = nil
    @compilation_errors = nil
    
    return false if self.xml.blank?
    
    doc = nil
    begin
      doc = Nokogiri::XML::Document.parse(self.part(XML_PART_NAME).content, nil, nil,
      Nokogiri::XML::ParseOptions::STRICT|Nokogiri::XML::ParseOptions::PEDANTIC|Nokogiri::XML::ParseOptions::NONET)
    rescue => e
      @compilation_errors = e.message + " near line #{e.line} column #{e.column}"
    end
    return true if @compilation_errors
    begin
      self.compile_xml!
    rescue => e
      # note errors somewhere that can be made visible and raise an exception
      @compilation_errors = e
    end
    return true if @compilation_errors
    return false
  end
  
protected

  def compile_xml!
    lib = Fabulator::Lib::Lib.new
    lib.compile_xml(self.xml)
    lib.register_library
    lib
  end
end
