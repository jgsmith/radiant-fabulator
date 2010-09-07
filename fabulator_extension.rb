$: << File.expand_path(File.dirname(__FILE__))+'/lib'

require 'fabulator'
require 'fabulator/template'
require 'fabulator/radiant'

require_dependency "#{File.expand_path(File.dirname(__FILE__))}/app/models/fabulator_page"

class FabulatorExtension < Radiant::Extension
  version "1.0"
  description "Applications as documents"
  url "http://github.com/jgsmith/radiant-fabulator"

  XML_PART_NAME = 'extended'

  extension_config do |config|
    config.gem 'fabulator'
    config.after_initialize do
      #run_something
    end
  end


  def activate
    FabulatorPage

    tab 'Fabulator' do
    end

    PagePart.class_eval do
      after_save :compile_xml

#      validates_each :content do |record, attr, value|
#        record.compile_xml
#      end

      def compile_xml
        if self.page.class_name == 'FabulatorPage' &&
           self.name == FabulatorExtension::XML_PART_NAME
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
                sm = Fabulator::Core::StateMachine.new
                sm.compile_xml(self.content)
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
end
