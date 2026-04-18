class ConnectedAppsController < ApplicationController
  def index
    @tokens = Current.user.api_tokens.active.order(created_at: :desc)
  end

  def destroy
    token = Current.user.api_tokens.find_by(id: params[:id])
    return redirect_to(connected_apps_path, alert: "Token not found.") if token.nil?

    token.update!(active: false)
    redirect_to connected_apps_path, notice: "Token revoked."
  end
end
