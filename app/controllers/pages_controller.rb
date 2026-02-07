class PagesController < ApplicationController
  allow_unauthenticated_access

  layout "landing"

  def home
    redirect_to dashboard_path if resume_session
  end
end
