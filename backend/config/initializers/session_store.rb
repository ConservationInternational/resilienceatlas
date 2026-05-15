# Be sure to restart your server when you modify this file.

Rails.application.config.session_store :cookie_store,
  key: "_neptis_session",
  secure: Rails.env.production?,  # HTTPS-only cookie in production
  http_only: true,                 # Not accessible from JavaScript
  same_site: :lax                  # Prevents CSRF from cross-site requests
