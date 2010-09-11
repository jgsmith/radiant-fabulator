class FabulatorLibrary < ActiveRecord::Base
  validates_presence_of :name
  validates_uniqueness_of :name

  belongs_to :updated_by, :class_name => 'User'
  belongs_to :created_by, :class_name => 'User'

  serialize :compiled_xml

  before_save :compile_xml

  def compile_xml
    lib = Fabulator::Lib::Lib.new
    begin
      lib.compile_xml(self.xml)
      lib.register_library
    rescue => e
      # add error
      Rails.logger.info("Error compiling library: #{e}")
    end
    self.compiled_xml = lib
  end
end
