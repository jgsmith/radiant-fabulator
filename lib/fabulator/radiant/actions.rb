require 'fabulator/tag_lib'
#require 'fabulator/radiant/actions/require_auth'

module Fabulator
  RADIANT_NS="http://dh.tamu.edu/ns/fabulator/radiant/1.0#"
  class FabulatorRequireAuth < StandardError
    def initialize(message = "") super; end
  end

  module Radiant
    module Actions
      class Lib < Fabulator::TagLib

        namespace RADIANT_NS

        #action 'require-auth', Fabulator::Radiant::Actions::RequireAuth

        #register_type 'user', {
        #}

        register_type 'page', {
          :ops => {
            :children => Proc.new { |p| Page.find(p.value.to_i).children.collect { |c| Lib.page_to_node(c, p) } },
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
              :convert => Proc.new { |p| p.anon_node(p.value, [ FAB_NS, 'string' ]) }
            }
          ],
        }

        # 'radiant' axis
        axis 'radiant' do |ctx|
          # returns the root 'Home' page for the site
          # children are addressable by their slug
          Lib.page_to_node(Page.find_by_parent_id(nil), ctx)
        end

        function 'find', [ RADIANT_NS, 'page' ] do |ctx, args|
          args[0].collect { |a|
            Lib.page_to_node(Page.find_by_parent_id(nil).find_by_url(a.to_s), ctx)
          }
        end

        function 'current-user' do |ctx, args|
          u = UserActionObserver.current_user
          if !u.nil?
            n = ctx.root.anon_node(u.id) #, [ RADIANT_NS, 'user' ])
            n.set_attribute('admin', u.admin?)
            return [ n ]
          else
            return [ ]
          end
        end

        def self.page_to_node(p, ctx)
          return nil if p.nil?
          p_node = ctx.root.anon_node(p.id, [ RADIANT_NS, 'page' ])
          p_node.name = p.slug
          p.parts.each do |pp|
            #pp_node = ctx.root.anon_node(pp.content, [ RADIANT_NS, 'page-part' ])
            #pp_node.name = pp.name
            #pp_node.set_attribute('filter', pp.filter)
            #p_node.set_attribute(pp.name, pp_node)
            p_node.set_attribute(pp.name, pp.content)
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
