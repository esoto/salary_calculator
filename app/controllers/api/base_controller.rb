module Api
  class BaseController < ActionController::API
    before_action :authenticate_token!

    attr_reader :current_api_token

    private

    def authenticate_token!
      token = bearer_token
      @current_api_token = ApiToken.authenticate(token)

      if @current_api_token
        Current.user_override = @current_api_token.user
      else
        render json: { error: "unauthorized" }, status: :unauthorized
      end
    end

    def bearer_token
      header = request.headers["Authorization"].to_s
      return nil unless header.start_with?("Bearer ")
      header.split(" ", 2).last
    end

    def require_scope!(scope)
      return if current_api_token&.has_scope?(scope)
      render json: { error: "insufficient_scope", required: scope }, status: :forbidden
    end
  end
end
