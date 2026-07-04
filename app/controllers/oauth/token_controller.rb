module Oauth
  class TokenController < ActionController::API
    include Oauth::RedirectUriAllowlist

    # Expense Tracker is a trusted first-party client and there is no
    # refresh-token flow, so tokens are issued with a long-lived TTL instead
    # of expiring silently every 90 days.
    TOKEN_TTL = 10.years

    def create
      return bad_request!("unsupported_grant_type") unless params[:grant_type] == "authorization_code"
      return bad_request!("invalid_redirect_uri") unless allowlisted_redirect?(params[:redirect_uri])

      record = OauthAuthorizationCode.consume(
        plaintext: params[:code],
        redirect_uri: params[:redirect_uri]
      )
      return bad_request!("invalid_grant") if record.nil?
      return bad_request!("invalid_grant") if record.user.nil?

      api_token = ApiToken.create!(
        user: record.user,
        name: "Expense Tracker (#{Date.current.iso8601})",
        scopes: record.scopes,
        expires_at: TOKEN_TTL.from_now
      )

      plaintext_token = api_token.token
      raise "ApiToken.token missing after create" if plaintext_token.blank?

      render json: {
        access_token: plaintext_token,
        token_type: "Bearer",
        scope: api_token.scopes,
        expires_in: (api_token.expires_at - Time.current).round.to_i
      }
    end

    private

    def bad_request!(reason)
      render json: { error: reason }, status: :bad_request
    end
  end
end
