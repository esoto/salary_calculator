module Oauth
  class AuthorizeController < ApplicationController
    SUPPORTED_SCOPES = %w[budget:read].freeze

    before_action :validate_params!

    def show
      @redirect_uri = params[:redirect_uri]
      @state = params[:state]
      @requested_scopes = requested_scope_list
      render :show
    end

    def create
      issued = OauthAuthorizationCode.issue(
        user: Current.user,
        redirect_uri: params[:redirect_uri],
        scopes: requested_scope_list.join(" ")
      )

      redirect_params = { code: issued.plaintext, state: params[:state] }
      redirect_to "#{params[:redirect_uri]}?#{redirect_params.to_query}",
                  allow_other_host: true
    end

    private

    def validate_params!
      if params[:state].blank?
        render plain: "missing state", status: :bad_request and return
      end

      unless allowlisted_redirect?(params[:redirect_uri])
        render plain: "invalid redirect_uri", status: :bad_request and return
      end

      invalid_scopes = requested_scope_list - SUPPORTED_SCOPES
      if invalid_scopes.any?
        render plain: "unsupported scopes: #{invalid_scopes.join(',')}", status: :bad_request and return
      end
    end

    def allowlisted_redirect?(uri)
      Rails.application.config.x.oauth.redirect_uri_allowlist.include?(uri)
    end

    def requested_scope_list
      params[:scopes].to_s.split(/\s+/).reject(&:blank?)
    end
  end
end
