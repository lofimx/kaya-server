class EverythingController < ApplicationController
  def index
    if params[:q].present?
      @angas = SearchService.new(Current.user, params[:q]).search
                           .order(filename: :desc)
    else
      @angas = Current.user.angas
                      .includes(:file_attachment)
                      .order(filename: :desc)
    end
  end
end
