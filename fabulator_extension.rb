$: << File.expand_path(File.dirname(__FILE__))+'/lib'

require 'fabulator_tags'

require_dependency "#{File.expand_path(File.dirname(__FILE__))}/app/models/fabulator_page"

class FabulatorExtension < Radiant::Extension
  version "0.0.9"
  description "Applications as documents"
  url "http://github.com/jgsmith/radiant-fabulator"

  XML_PART_NAME = 'extended'

  extension_config do |config|
#    config.gem 'fabulator'
    config.after_initialize do
      require 'fabulator'
      require 'fabulator/lib'
      require 'fabulator/template'
      require 'fabulator/radiant'
    end
  end

  def scripts
    @@scripts ||= [ ]
    @@scripts
  end

  def css
    @@css ||= [ ]
    @@css
  end

  def activate
    FabulatorPage
    FabulatorFilter

    tab 'Fabulator' do
      add_item("Editions", "/admin/fabulator/editions")
      add_item("Libraries", "/admin/fabulator/libraries")
    end
    Radiant::AdminUI.class_eval do
      attr_accessor :libraries
      alias_method :fabulator_library, :libraries
      attr_accessor :editions
      alias_method :fabulator_edition, :editions
    end
    admin.libraries = load_default_fabulator_library_regions
    admin.editions  = load_default_fabulator_edition_regions
    admin.page.edit.add :form_top, "parse_errors"

    Page.class_eval {
      include FabulatorTags
    }

    PagePart.class_eval do
      #after_save :compile_xml

      def compile_xml
        if self.page.class_name == 'FabulatorPage' &&
           self.name == FabulatorExtension::XML_PART_NAME

          FabulatorLibrary.all.each do |library|
            if library.compiled_xml.is_a?(Fabulator::Lib::Lib)
              library.compiled_xml.register_library
            end
          end

          old_compiled_xml = self.page.compiled_xml
          if self.content.nil? || self.content == ''
            self.page.compiled_xml = nil
          else
            # compile
            #isa = Fabulator::TagLib.get_local_attr(doc.root, Fabulator::FAB_NS, 'is-a')
            isa = nil
            sm = nil
            if isa.nil?
              begin
                compiler = Fabulator::Compiler.new
                sm = compiler.compile(self.content)
              rescue => e
                self.errors.add(:content, "Compiling the XML application resulted in the following error: #{e}")
              end
            else
              supersm_page = self.page.find_by_url(isa)
              if supersm_page.nil? || supersm_page.is_a?(FileNotFoundPage) || !supersm_page.is_a?(FabulatorPage) || supersm_page.state_machine.nil?
                raise "File Not Found: unable to find #{isa}"
              end
              sm = supersm_page.state_machine.clone
              begin
                sm.compile_xml(self.content)
              rescue => e
                self.errors.add(:content, "Compiling the XML application resulted in the following error: #{e}")
              end
            end
            self.page.compiled_xml = YAML::dump(sm)
          end
          if old_compiled_xml != self.page.compiled_xml
            self.page.save
          end
        end
      end
    end
  end

  def load_default_fabulator_library_regions
    returning OpenStruct.new do |library|
      library.edit = Radiant::AdminUI::RegionSet.new do |edit|
        edit.main.concat %w{edit_header edit_form}
        edit.form.concat %w{edit_title edit_content}
        edit.form_bottom.concat %w{edit_buttons edit_timestamp}
      end
      library.index = Radiant::AdminUI::RegionSet.new do |index|
        index.top.concat %w{help_text}
        index.thead.concat %w{title_header modify_header}
        index.tbody.concat %w{title_cell modify_cell}
        index.bottom.concat %w{new_button}
      end
      library.new = library.edit
    end
  end
  
  def load_default_fabulator_edition_regions
    returning OpenStruct.new do |edition|
      edition.edit = Radiant::AdminUI::RegionSet.new do |edit|
        edit.main.concat %w{edit_header edit_form}
        edit.form.concat %w{edit_title edit_content}
        edit.form_bottom.concat %w{edit_buttons edit_timestamp}
      end
      edition.index = Radiant::AdminUI::RegionSet.new do |index|
        index.top.concat %w{help_text}
        index.thead.concat %w{title_header size_header modify_header}
        index.tbody.concat %w{title_cell size_cell modify_cell}
        index.bottom.concat %w{new_button}
      end
      edition.new = edition.edit
    end
  end

end
