module Fabulator
  RADIANT_NS="http://dh.tamu.edu/ns/fabulator/radiant/1.0#"
  module Radiant
    module Actions
      class Lib
        include Fabulator::ActionLib

        register_namespace RADIANT_NS

        register_type 'page', {
          :ops => {
            :children => Proc.new { |p| p.value.children.collect { |c| Lib.page_to_node(c, p) } },
          },
        }

        # page parts are attributes of a page
        # as are @name, @breadcrumb, @description, @keywords
        #        @layout, @page-type, @status
        # slug is the node name
        # page parts have attributes @filter
        register_type 'page-part', {
          :to => [
            { :type => [ FAB_NS, 'string' ],
              :weight => 1.0,
              :convert => Proc.new { |p| p.value }
            }
          ],
        }

        # 'radiant' axis
        axis 'radiant' do |ctx|
          # returns the root 'Home' page for the site
          # children are addressable by their slug
          Lib.page_to_node(Page.find_by_parent_id(nil), ctx)
        end

        def self.page_to_node(p, ctx)
          p_node = ctx.anon_node(p, [ RADIANT_NS, 'page' ])
          p_node.name = p.slug
          p.parts.each do |pp|
            pp_node = ctx.anon_node(pp.content, [ RADIANT_NS, 'page-part' ])
            pp_node.name = pp.name
            #pp_node.set_attribute('filter', pp.filter)
            p_node.set_attribute(pp.name, pp_node)
          end
          p_node.set_attribute('title', p.title)
          p_node.set_attribute('breadcrumb', p.breadcrumb)
          p_node.set_attribute('description', p.description)
          p_node.set_attribute('keywords', p.keywords)
          #p_node.set_attribute('layout', p.layout)
          #p_node.set_attribute('page-type', p.page_type)
          #p_node.set_attribute('status', p.status)
          p_node
        end
      end
    end
  end
end
