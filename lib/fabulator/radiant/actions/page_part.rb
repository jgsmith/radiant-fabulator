module Fabulator
  module Radiant
    module Actions
      class PagePart < Fabulator::Action

        namespace Fabulator::RADIANT_NS

        attribute :name, :static => false, :eval => true
        attribute :filter, :static => false, :eval => true

        has_select
        has_actions

        def run(context, autovivify = false)
          content = []
          @context.with(context) do |ctx|
            if self.has_select?
              content = self.select(ctx)
            else
              content = self.run_actions(ctx)
            end
            content = content.collect{ |c| c.to([FAB_NS, 'string'], ctx).value }.join('')
            ctx.get_scoped_info('radiant/page/parts')[self.name(ctx).first.to_s] = {
              :content => content,
              :filter => self.filter(ctx).first.to_s
            }
          end
          []
        end

      end
    end
  end
end
