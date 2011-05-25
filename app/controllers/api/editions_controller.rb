class Api::EditionsController < ApplicationController

  def show
    @edition = FabulatorEdition.find(:first, :conditions => [ "name = ?", params[:id] ])
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
