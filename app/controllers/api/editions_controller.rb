class Api::EditionsController < ApplicationController
  only_allow_access_to :show,
    :when => [:admin],
    :denied_url => { :controller => 'admin/pages', :action => 'index' },
    :denied_message => 'You must have admin privileges to perform this action.'
    
  def show
    @edition = FabulatorEdition.find(params[:id])
    respond_to do |format|
      format.json { 
        render :json => { 
          :name => @edition.name, 
          :size => @edition.filesize, 
          :description => @edition.description
        }.to_json 
      }
      format.html {
        send_file(
          @edition.filepath + '/' + @edition.filename
        )
      }
    end
  end
end
