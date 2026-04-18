class ConnectedAppsController < ApplicationController
  before_action :require_authentication

  def index
    @tokens = Current.user.api_tokens.active.order(created_at: :desc)
  end

  def destroy
    token = Current.user.api_tokens.find_by(id: params[:id])
    return head(:not_found) if token.nil?

    token.update!(active: false)
    redirect_to connected_apps_path, notice: "Token revoked."
  end
end
