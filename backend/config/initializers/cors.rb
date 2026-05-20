Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    cors_origins = ENV.fetch("CORS_WHITELIST") do
      raise "CORS_WHITELIST environment variable is required in production" if Rails.env.production?

      "localhost"
    end

    origins cors_origins

    resource "*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head]
  end
end
