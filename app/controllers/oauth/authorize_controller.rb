module Oauth
  class AuthorizeController < ApplicationController
    include Oauth::RedirectUriAllowlist

    SUPPORTED_SCOPES = %w[budget:read].freeze

    before_action :validate_params!

    def show
      @redirect_uri = params[:redirect_uri]
      @state = params[:state]
      @requested_scopes = requested_scope_list
      session[:pending_oauth_consent] = {
        "scopes" => @requested_scopes,
        "redirect_uri" => @redirect_uri,
        "state" => @state
      }
      render :show
    end

    def create
      consented = session.delete(:pending_oauth_consent)
      unless consented && consented["redirect_uri"] == params[:redirect_uri] && consented["state"] == params[:state]
        render plain: "consent state mismatch", status: :bad_request and return
      end

      issued = OauthAuthorizationCode.issue(
        user: Current.session.user,
        redirect_uri: params[:redirect_uri],
        scopes: consented["scopes"].join(" ")
      )

      uri = URI.parse(params[:redirect_uri])
      existing_query = Rack::Utils.parse_nested_query(uri.query.to_s)
      uri.query = existing_query.merge("code" => issued.plaintext, "state" => params[:state]).to_query
      response.set_header("Referrer-Policy", "no-referrer")
      redirect_to uri.to_s, allow_other_host: true
    end

    private

    def validate_params!
      if params[:state].blank?
        render plain: "missing state", status: :bad_request and return
      end

      unless allowlisted_redirect?(params[:redirect_uri])
        render plain: "invalid redirect_uri", status: :bad_request and return
      end

      if requested_scope_list.empty?
        render plain: "missing scopes", status: :bad_request and return
      end

      invalid_scopes = requested_scope_list - SUPPORTED_SCOPES
      if invalid_scopes.any?
        render plain: "unsupported scopes: #{invalid_scopes.join(',')}", status: :bad_request and return
      end
    end

    def requested_scope_list
      params[:scopes].to_s.split(/\s+/).reject(&:blank?)
    end
  end
end
