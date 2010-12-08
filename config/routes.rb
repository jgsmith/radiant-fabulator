ActionController::Routing::Routes.draw do |map|
  map.namespace 'admin' do |admin|
    admin.namespace 'fabulator', :member => { :remove => :get } do |fab|
      fab.resources :libraries
    end
  end
end

