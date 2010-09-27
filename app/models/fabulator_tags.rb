module FabulatorTags
  include Radiant::Taggable

  class TagError < StandardError; end

  desc %{
  }
  tag 'fabulator' do |tag|
    tag.expand
  end

  desc %{
    Adds links to the javascript and css for jquery.
  }
  tag 'fabulator:resources' do |tag|
    %{
    <link rel="stylesheet" href="/stylesheets/fabulator/smoothness/jquery-ui-1.8.5.custom.css" />
    <script src="/javascripts/fabulator/jquery-1.4.2.min.js" type="text/javascript" />
    <script src="/javascripts/fabulator/jquery-ui-1.8.5.custom.min.js" type="text/javascript" />
    }
  end
end
