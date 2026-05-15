# Rack::Attack — brute-force and credential-stuffing protection for the admin login endpoint.
# Limits are intentionally permissive enough not to affect normal human usage.

class Rack::Attack
  # ── Safelist ─────────────────────────────────────────────────────────────────
  # Never throttle requests from localhost (development/test environments).
  safelist("allow-localhost") do |req|
    req.ip == "127.0.0.1" || req.ip == "::1"
  end

  # ── Throttles ────────────────────────────────────────────────────────────────

  # Limit any single IP to 5 POST attempts on the admin sign-in endpoint per 20 seconds.
  # This stops fast automated brute-force from a single source.
  throttle("admin/sign_in/ip", limit: 5, period: 20.seconds) do |req|
    req.ip if req.path == "/admin/sign_in" && req.post?
  end

  # Limit any email address to 10 login attempts per 5 minutes.
  # This stops slow distributed attacks that rotate IPs but target the same account.
  throttle("admin/sign_in/email", limit: 10, period: 5.minutes) do |req|
    if req.path == "/admin/sign_in" && req.post?
      # Normalise to lowercase to prevent trivial bypass via case variation.
      req.params.dig("admin_user", "email").to_s.downcase.presence
    end
  end

  # ── Response ─────────────────────────────────────────────────────────────────
  # Return a plain 429 with a short retry hint instead of raising an exception.
  self.throttled_responder = lambda do |env|
    [
      429,
      {"Content-Type" => "text/plain", "Retry-After" => "60"},
      ["Too many login attempts. Please wait before trying again.\n"]
    ]
  end
end
