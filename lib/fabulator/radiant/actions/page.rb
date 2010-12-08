module Fabulator
  module Radiant
    module Actions
      class Page < Fabulator::Action

        namespace Fabulator::RADIANT_NS

        attribute 'child-of', :static => false, :eval => true, :as => 'parent'
        attribute :title, :static => false, :eval => true
        attribute :slug, :static => false, :eval => true
        attribute :status, :static => false, :eval => true
        attribute :layout, :static => false, :eval => true
        attribute :description, :static => false, :eval => true
        attribute :breadcrumb, :static => false, :eval => true

        has_select
        has_actions

        def run(context, autovivify = false)
          @context.with(context) do |ctx|
            ## collect page parts
            parents = self.parent(ctx)
            if parents.nil? || parents.empty? # default is root page
              parents = self.select(ctx)
            end

            if parents.nil? || parents.empty? # default is root page
              parents = [ ctx.root.anon_node('/') ]
            end

            parents = parents.collect{ |pp| pp.to([ Fabulator::RADIANT_NS, 'page' ], ctx) } - [ nil ]
            # TODO: remove any non-found pages (404 pages, for example)

            return [] if parents.empty?

            s = self.slug(ctx).first

            return [] if s.nil? && !self.has_select?

            using_children = false

            if s.nil?
              s = parents.first
              
            else
              using_children = true
              s = s.to_s
            end

            ctx.set_scoped_info('radiant/page/parts', { })
            self.run_actions(ctx)

            ## update or create page - requires parent to exist
            page_parts_info = ctx.get_scoped_info('radiant/page/parts')

            parents.each do |page_id|
              page = ::Page.find(page_id.value)
              child = nil
              if using_children
                child = page.children.select{ |c| c.slug == s }.first
                if child.nil?
                  child = page.class.new_with_defaults()

                  child.slug = s
                  child.parent_id = page.id
                end
              else
                child = page
              end

              begin
                child.status = Status[self.status(ctx).first.to_s]
              rescue
                # ignore status changes if status doesn't exist
              end

              begin
                child.description = self.description(ctx).first.to_s
              rescue
              end

              begin
                child.title = self.title(ctx).first.to_s
              rescue
              end

              begin
                child.breadcrumb = self.breadcrumb(ctx).first.to_s || child.title
              rescue
                child.breadcrumb = child.title
              end

              if child.breadcrumb.nil? || child.breadcrumb == ''
                child.breadcrumb = child.title
              end

              child.class_name = child.class.name

              page_parts_info.each_pair do |part_name, part_info|
                part = child.part(part_name)
                if part.nil?
                  part = ::PagePart.new(:name => part_name)
                end
                if part_info[:filter]
                  part.filter_id = part_info[:filter]
                end
                part.content = part_info[:content]
                if !child.has_part?(part_name)
                  child.parts.concat part
                end
              end
              child.save!
              child.parts.each do |part|
                if part.content.nil?
                  part.content = ''
                  part.save
                end
              end
            end
          end
          [] # we return nothing
        end

      end
    end
  end
end
