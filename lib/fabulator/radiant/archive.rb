# This is the base class for any extensions archive object
# The extension should register the archive object like so:
#   FabulatorExtension.archives << MyArchiveClass.new(...)

module Fabulator
  module Radiant
    class Archive
      @@readers = { }
      @@writers = { }
      
      @@namespace_deps = { }
      @@namespaces = { }
      @@object_namespaces = { }
      @@versions = { }
#      @@folders = { }
#      @@files = { }
#      @@data = { }
      
      def self.inherited(base)
        base.extend(ClassMethods)
      end
      
      def self.namespaces
        @@namespaces
      end
      
      def self.object_namespaces
        @@object_namespaces
      end
      
      def self.versions
        @@versions
      end
      
      def self.writers
        @@writers
      end
      
      def self.readers
        @@readers
      end
      
      def writer
        Fabulator::Radiant::Archive.writers[self.class.name]
      end
      
      def reader
        Fabulator::Radiant::Archive.readers[self.class.name]
      end
      
      def depends_on
        Fabulator::Radiant::Archive.namespace_deps[self.class.name] || [ ]
      end
      
      module ClassMethods
        def inherited(subclass)
          super
        end

        def version(v)
          Fabulator::Radiant::Archive.versions[self.name] = v
        end

        def namespace(ns)
          Fabulator::Radiant::Archive.namespaces[ns] = self.new
          Fabulator::Radiant::Archive.object_namespaces[self.name] = ns
        end
        
        def depends_on(*ns_array)
          Fabulator::Radiant::Archive.namespace_deps[self.name] = ns_array
        end
         
        def reading(&block)
          Fabulator::Radiant::Archive.readers[self.name] ||= Reader.new(
            Fabulator::Radiant::Archive.object_namespaces[self.name], 
            Fabulator::Radiant::Archive.versions[self.name]
          )
          if block
            Fabulator::Radiant::Archive.readers[self.name].instance_eval &block
          end
        end
            
        def writing(&block)
          Fabulator::Radiant::Archive.writers[self.name] ||= Writer.new(
            Fabulator::Radiant::Archive.object_namespaces[self.name], 
            Fabulator::Radiant::Archive.versions[self.name]
          )
          if block
            Fabulator::Radiant::Archive.writers[self.name].instance_eval &block
          end
        end
      end
      
      class Writer
        attr_reader :folders, :files, :data, :ns, :version
        
        def initialize(ns, version)
          @ns = ns
          @version = version
          @folders = { }
          @files = { }
          @data = { }
          @data_keys = [ ]
        end
        
        def archiver
          Fabulator::Radiant::Archive.namespaces[@ns]
        end
        
        def folder(s, f)
          @folders[s.to_sym] ||= []
          @folders[s.to_sym] << f
        end
        
        def file(s, f)
          @files[s.to_sym] ||= []
          @files[s.to_sym] << f
        end
        
#        data :config do |io|
#          Config.find(:all).each do |c|
#            io << c.attributes
#          end
#        end
        
        def data(nom = :default, model_class = nil, attr_mapping = { }, &block)
          @data[nom.to_sym] = {
            :block => block,
            :model => model_class,
            :attrs => attr_mapping
          }
          @data_keys << nom.to_sym
        end
        
        def add_to_archive(archive)
          # add folders
          # valid folder locations: :system, :public
          if !@folders[:system].nil?
            archive.add_folders(:system, '/', @folders[:system])
          end
          if !@folders[:public].nil?
            archive.add_folders(:public, '/public/', @folders[:public])
          end
          
          # then files
          
          # then data
          @data_keys.each do |d_key|
            if @data[d_key][:model].nil?
              @archive.add_data(d_key, &@data[d_key][:block])
            else
              archive.add_data(d_key) do |io|
                @data[d_key][:model].find(:all).each do |m|
                  if @data[d_key][:block]
                    attrs = @data[d_key][:block].yield m
                  else
                    attrs = m.attributes
                  end
                  if @data[d_key][:attrs] && !attrs.empty?
                    old_keys = [ ]
                    save_keys = [ ]
                    @data[d_key][:attrs].each_pair do |to,from|
                      attrs[to] = attrs[from]
                      old_keys << from
                      save_keys << to
                    end
                    (old_keys - save_keys).each { |k| attrs.delete(k) }
                  end
                  io << attrs
                end
              end
            end
          end
        end
      end
      
      class Reader
        attr_reader :for_data

        def initialize(ns, version)
          @ns = ns
          @version = version
          @data = { }
        end
        
        # passes in a name and an object that feeds one item each time
        def data(nom = :default, &block)
          @data[nom.to_sym] = block
        end
        
        def take_from_archive(archive)
          writer = Fabulator::Radiant::Archive.writers[Fabulator::Radiant::Archive.namespaces[@ns]]
          # we use the folder/file configs from the writer to figure out what look for when reading
          
        end
      end
      
      class ArchiveWriter
        def initialize(base_dir)
          @base_dir = base_dir
        end
        
        def create_archive
          namespaces = { }
          ns_count = 0
          Dir.mkdir(@base_dir + "/extensions")
          # we want to write out in order of dependencies
          # assume FAB_NS is a dependecy for everything else
          unused_writers = Fabulator::Radiant::Archive.writers.values
          available_namespaces = unused_writers.collect{|w| w.ns}
          writers = unused_writers.select{ |w| w.ns == Fabulator::FAB_NS }
          unused_writers -= writers
          moved_writer = true
          while(!unused_writers.empty? && moved_writer)
            moved_writer = false
            used_namespaces = writers.collect{ |w| w.namespace }
            new_writers = unused_writers.select{ |w| 
              ((w.archiver.depends_on & available_namespaces) - used_namespaces - [w.ns]).empty? 
            }
            moved_writer = !new_writers.empty?
            unused_writers -= new_writers
            writers += new_writers
          end
          
          writers += unused_writers
            
          writers.each do |writer|
            ns_count += 1
            namespaces[writer.ns] = {
              :extension_directory => ns_count.to_s,
              :version => writer.version
            }
            @current_dir = @base_dir + "/extensions/#{ns_count}"
            Dir.mkdir(@current_dir) unless File.directory?(@current_dir)
            writer.add_to_archive(self)
          end
          
          
          # now that the directory tree is built and all the content is there, create the tarball
          # and gzip it
          # we want this to open up as ./edition-#{d}/
          # and be named edition-#{d}.tgz
        end
        
        def add_folders(type, dir_prefix, dirs)
        end
        
        def add_data(nom, &block)
          data_file = @current_dir + "/data/#{nom}"
          Dir.mkdir(@current_dir + "/data") unless File.directory?(@current_dir + "/data")
          @is_first = true
          File.open(data_file, "w") { |io|
            @io = io
            @io << '['
            yield self
            @io << ']'
          }
        end
        
        def <<(obj)
          # we don't write out empty objects
          return if obj.is_a?(Hash) && obj.empty?
          
          if !@is_first
            @io << ",\n"
          end
          @is_first = false
          # convert obj to JSON and write to stream
          @io << obj.to_json
        end
      end
      
      class ArchiveReader
        def initialize(base_dir)
          @base_dir = base_dir
        end
        
        # this will bring everything in the archive into the application, overwriting what is there
        def restore_archive
        end
      end
    end
  end
end