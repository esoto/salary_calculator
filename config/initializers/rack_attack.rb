class Rack::Attack
  throttle("api/ip", limit: 300, period: 5.minutes) do |req|
    req.ip if req.path.start_with?("/api/")
  end

  throttle("api/token", limit: 600, period: 5.minutes) do |req|
    if req.path.start_with?("/api/") && (auth = req.get_header("HTTP_AUTHORIZATION"))
      auth[/\ABearer\s+(.+)\z/i, 1]&.strip
    end
  end

  self.throttled_responder = lambda do |request|
    [ 429, { "Content-Type" => "application/json" }, [ '{"error":"rate_limit_exceeded"}' ] ]
  end
end

Rack::Attack.enabled = false if Rails.env.test?
