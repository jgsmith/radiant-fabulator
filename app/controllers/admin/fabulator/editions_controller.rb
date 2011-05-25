module Admin
  module Fabulator
    class EditionsController < Admin::ResourceController
      only_allow_access_to :index, :show, :new, :create, :remove, :destroy,
        :when => [:designer, :admin],
        :denied_url => { :controller => 'admin/pages', :action => 'index' },
        :denied_message => 'You must have designer privileges to perform this action.'

      def model_class
        FabulatorEdition
      end

      def show
        respond_to do |format|
          format.xml { super }
          format.html { @fabulator_edition = FabulatorEdition.find(params[:id]) }# { redirect_to edit_admin_fabulator_editions_path(params[:id]) }   
        end
      end
    end
  end
end

