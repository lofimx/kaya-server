class AngaController < ApplicationController
  def preview
    @anga = Current.user.angas.find(params[:id])

    if @anga.file.attached?
      send_data @anga.file.download,
                filename: @anga.filename,
                type: @anga.file.content_type,
                disposition: "inline"
    else
      head :not_found
    end
  end
end
