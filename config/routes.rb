ActionController::Routing::Routes.draw do |map|
  map.namespace 'admin' do |admin|
    admin.namespace 'fabulator', :member => { :remove => :get } do |fab|
      fab.resources :libraries
      fab.resources :editions
    end
  end
  map.namespace 'api' do |api|
    api.resources :editions
  end
end

