require 'fabulator/radiant/archive'

class FabulatorEdition < ActiveRecord::Base
  validates_presence_of :name
  validates_uniqueness_of :name

  belongs_to :updated_by, :class_name => 'User'
  belongs_to :created_by, :class_name => 'User'

  after_create :create_archive

  # we want to store the edition content in a file, not in the database
  def filename
    "edition-#{self.id}.tgz"
  end
  
  def build_dirname
    "edition-#{self.id}"
  end
  
  def filepath
    RAILS_ROOT + '/fabulator/editions'
  end
  
  def file_size
    File.size?(self.filepath + "/" + filename) || 0
  end
  
  ## we hand off to the Fabulator::Radiant::Archive* classes to handle the details
  ## see the Fabulator::Radiant::Archive file for details
  def create_archive
    Dir.mkdir(self.filepath + "/" + self.build_dirname)
    archive = Fabulator::Radiant::Archive::ArchiveWriter.new(self.filepath + "/" + self.build_dirname)
    archive.create_archive
  end
  
  def restore_archive
    archive = Fabulator::Radiant::Archive::ArchiveReader.new(self.filepath + "/" + self.filename)
    archive.restore_archive
  end
end

#
# An edition captures everything about a site
# It's possible to cut a new edition as well as restore a site to a previous edition.
# You can also load editions from a saved edition
# loading a saved edition and going live with it is one way to port a site from one server to another
# eventually, this is how projects can be saved and sent to a central repository
#