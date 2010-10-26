class FabulatorFilter < TextFilter
  def filter(text)
    ## we *really* need to know the current page we're working with
    begin
      ctx = ( @@page.fabulator_context rescue Fabulator::Expr::Context.new )
      text_parser = Fabulator::Template::Parser.new
      parsed = text_parser.parse(ctx, text)
      parsed.add_default_values(ctx.with_root(ctx.root.roots['data']))
      r = parsed.to_html({ :theme => FabulatorTags.theme_for_this_page || 'coal' })
      r.gsub!(/^\s*<\?xml\s+.*?\?>/, '')
Rails.logger.info("Filter produces: [#{r}]")
      r
    rescue => e
      "Unable to parse contents: #{e}"
    end
  end

  def self.set_page(p)
    @@page = p
  end

  def self.reset_page
    @@page = nil
  end
end
