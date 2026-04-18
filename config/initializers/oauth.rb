Rails.application.config.x.oauth = ActiveSupport::OrderedOptions.new
Rails.application.config.x.oauth.redirect_uri_allowlist =
  ENV.fetch("OAUTH_REDIRECT_URI_ALLOWLIST", "").split(",").map(&:strip).reject(&:blank?)
