Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    cors_origins = ENV.fetch("CORS_WHITELIST") do
      raise "CORS_WHITELIST environment variable is required in production" if Rails.env.production?

      "localhost"
    end

    # Support comma-separated list of allowed origins
    origins_list = cors_origins.split(",").map(&:strip)

    # Optionally allow an additional regex pattern for subdomain matching.
    # Example: CORS_ORIGIN_REGEX='\Ahttps://([\w-]+\.)*resilienceatlas\.org\z'
    if (regex_pattern = ENV["CORS_ORIGIN_REGEX"].presence)
      origins_list << Regexp.new(regex_pattern)
    end

    origins(*origins_list)

    resource "*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head]
  end
end
