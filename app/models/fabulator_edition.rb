class FabulatorEdition < ActiveRecord::Base
  validates_presence_of :name
  validates_uniqueness_of :name
  

  belongs_to :updated_by, :class_name => 'User'
  belongs_to :created_by, :class_name => 'User'

  # we want to store the edition content in a file, not in the database
  def filename
    "edition-#{self.id}.tgz"
  end
  
  def filepath
    RADIANT_ROOT + '/fabulator/editions'
  end
  
  def create_archive
    # we want to go through each fabulator-related radiant extension and call their
    # archive method if it exists
    tgz = Zlib::GzipWriter.new(File.open(self.filepath + '/' + self.filename, 'wb'))
    Archive::Tar::Writer.new(tgz) {|ar|
      @archive = ar
      @archive_opts = {
        :mode => 0x664,
        :mtime => Time.localtime,
        :uid => 0,
        :gid => 0
      }
      Radiant::ExtensionLoader.extensions.each do |extension|
        if extension.has_method?('augment_fabulator_edition')
          @current_extension_name = extension.class.name
          @current_extension_version = extension.fabulator_edition_version
          @archive.mkdir(@current_extension_name)
          @archive.mkdir(@current_extension_name + '/content')
          @archive.mkdir(@current_extension_name + '/folders')
          @archive.mkdir(@current_extension_name + '/files')
          extension.augment_fabulator_edition(self)
          @archive.add_file(@current_extension_name + '/VERSION', @archive_opts) { |stream|
            stream.write(@current_extension_version + "\n")
          }
        end
      end
      @archive.add_file('VERSION', @archive_opts) { |stream|
        stream.write('0.0.1')
      }
      @archive.add_file('README', @archive_opts) { |stream|
        stream.write(self.name + "\n\n" + self.description)
      }
    }  
    @archive = nil
    @current_extension_name = nil
    @current_extension_version = nil
  end
  
  # adds the content with the label to the extension's area in the archive
  def add_content(label, content)
    @archive.add_file(@current_extension_name + '/content/' + label, @archive_opts) { |stream|
      stream.write(content)
    }
  end
  
  def add_folder(label, dirpath)
    
  end
  
  def add_file(label, filepath)
  end
  
  def restore_archive
    Radiant::ExtensionLoader.extensions.each do |extension|
      if extension.has_method?('restore_from_fabulator_edition')
        # we need to make sure the version in the archive doesn't exceed the version the extension can handle
        
      end
    end
  end
end

#
# An edition captures everything about a site
# It's possible to cut a new edition as well as restore a site to a previous edition.
# You can also load editions from a saved edition
# loading a saved edition and going live with it is one way to port a site from one server to another
# eventually, this is how projects can be saved and sent to a central repository
#