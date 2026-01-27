class PagesController < ApplicationController
  allow_unauthenticated_access

  def home
    redirect_to app_everything_path if authenticated?
  end
end
