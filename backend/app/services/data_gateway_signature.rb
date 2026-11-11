class DataGatewaySignature
  def self.for(resource)
    secret = ENV.fetch("DATA_GATEWAY_SECRET")
    raise ArgumentError, "DATA_GATEWAY_SECRET must contain at least 32 bytes" if secret.bytesize < 32

    expires = (Time.current + 1.minute).to_i
    digest = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{expires}\n#{resource}")
    "#{expires}:#{digest}"
  end
end
