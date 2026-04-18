module Oauth
  class TokenController < ActionController::API
    def create
      return bad_request!("unsupported_grant_type") unless params[:grant_type] == "authorization_code"
      return bad_request!("invalid_redirect_uri") unless allowlisted_redirect?(params[:redirect_uri])

      record = OauthAuthorizationCode.consume(
        plaintext: params[:code],
        redirect_uri: params[:redirect_uri]
      )
      return bad_request!("invalid_grant") if record.nil?

      api_token = ApiToken.create!(
        user: record.user,
        name: "Expense Tracker (#{Date.current.iso8601})",
        scopes: record.scopes
      )

      render json: {
        access_token: api_token.token,
        token_type: "Bearer",
        scope: api_token.scopes
      }
    end

    private

    def allowlisted_redirect?(uri)
      Rails.application.config.x.oauth.redirect_uri_allowlist.include?(uri)
    end

    def bad_request!(reason)
      render json: { error: reason }, status: :bad_request
    end
  end
end
