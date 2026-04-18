module Oauth
  module RedirectUriAllowlist
    extend ActiveSupport::Concern

    private

    def allowlisted_redirect?(uri)
      Rails.application.config.x.oauth.redirect_uri_allowlist.include?(uri)
    end
  end
end
