module FabulatorTags
  include Radiant::Taggable

  class TagError < StandardError; end

  mattr_accessor :theme_for_this_page

  desc %{
  }
  tag 'fabulator' do |tag|
    tag.expand
  end

  desc %{
    Adds links to the javascript and css for jquery.
  }
  tag 'fabulator:resources' do |tag|
    theme = tag.attr['theme'] || 'coal'
    FabulatorTags.theme_for_this_page = theme
    ret = %{
    <link rel="stylesheet" href="/stylesheets/fabulator/css/fss-reset.css" />
    <link rel="stylesheet" href="/stylesheets/fabulator/css/fss-layout.css" />
    <link rel="stylesheet" href="/stylesheets/fabulator/css/fss-text.css" />
    <link rel="stylesheet" href="/stylesheets/fabulator/css/fss-theme-#{theme}.css" />
    <link rel="stylesheet" href="/stylesheets/fabulator/css/smoothness/jquery-ui-1.8.5.custom.css" />
    <link rel="stylesheet" href="/stylesheets/fabulator/core.css" />
    }

    FabulatorExtension.css.each do |c|
      ret += %{<link rel="stylesheet" href="/stylesheets/#{c}" />}
    end

    ret += %{
    <script src="/javascripts/fabulator/InfusionAll.js" type="text/javascript"></script>
    <script src="/javascripts/fabulator/jquery-ui-1.8.5.custom.min.js" type="text/javascript"></script>
    <script src="/javascripts/fabulator/jquery.tools.min.js" type="text/javascript"></script>
    <script src="/javascripts/fabulator/core.js" type="text/javascript"></script>
    }

    FabulatorExtension.scripts.each do |c|
      ret += %{<script src="/javascripts/#{c}" type="text/javascript"></script>}
    end

    ret
  end
end
