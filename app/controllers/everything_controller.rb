class EverythingController < ApplicationController
  def index
    @angas = Current.user.angas
                    .includes(:file_attachment)
                    .order(filename: :desc)

    if params[:q].present?
      @angas = @angas.where("filename LIKE ?", "%#{params[:q]}%")
    end
  end
end
