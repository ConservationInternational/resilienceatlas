require "net/http"
require "nokogiri"

class TileCloudfrontInvalidation
  class Error < StandardError; end

  def submit(paths, reference)
    distributions.to_h do |distribution|
      items = paths.map { |path| "<Path>#{ERB::Util.html_escape(path)}</Path>" }.join
      xml = "<InvalidationBatch xmlns=\"http://cloudfront.amazonaws.com/doc/2020-05-31/\"><Paths><Quantity>#{paths.size}</Quantity><Items>#{items}</Items></Paths><CallerReference>#{reference}</CallerReference></InvalidationBatch>"
      response = request(:post, "/2020-05-31/distribution/#{distribution}/invalidation", xml)
      id = parse(response).at_xpath("//*[local-name()='Invalidation']/*[local-name()='Id']")&.text
      raise Error, "CloudFront did not return an invalidation identifier" if id.blank?
      [distribution, id]
    end
  end

  def completed?(distribution, id)
    validate_identifier!(distribution)
    validate_identifier!(id)
    response = request(:get, "/2020-05-31/distribution/#{distribution}/invalidation/#{id}")
    status = parse(response).at_xpath("//*[local-name()='Status']")&.text
    raise Error, "CloudFront returned an unknown invalidation status" unless %w[InProgress Completed].include?(status)
    status == "Completed"
  end

  private

  def distributions
    ids = ENV.fetch("TILE_CLOUDFRONT_DISTRIBUTION_IDS", "").split(",").map(&:strip).reject(&:empty?)
    raise Error, "CDN invalidation is not configured; operator submission and confirmation are required" if ids.empty?
    ids.each { |id| validate_identifier!(id) }
    ids
  end

  def validate_identifier!(id)
    raise Error, "Invalid CloudFront identifier" unless /\A[A-Za-z0-9_-]+\z/.match?(id)
  end

  def parse(response)
    Nokogiri::XML(response.body) { |config| config.strict.nonet }
  rescue Nokogiri::XML::SyntaxError
    raise Error, "CloudFront returned invalid XML"
  end

  def request(method, path, body = nil)
    require "aws-sdk-core"
    require "aws-sigv4"
    credentials = Aws::CredentialProviderChain.new.resolve
    raise Error, "CloudFront credentials are unavailable" unless credentials
    uri = URI("https://cloudfront.amazonaws.com#{path}")
    signed = Aws::Sigv4::Signer.new(service: "cloudfront", region: "us-east-1", credentials_provider: credentials)
      .sign_request(http_method: method.to_s.upcase, url: uri, headers: {"content-type" => "application/xml"}, body: body.to_s)
    request = (method == :post) ? Net::HTTP::Post.new(uri) : Net::HTTP::Get.new(uri)
    signed.headers.each { |key, value| request[key] = value }
    request.body = body if body
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 15) { |http| http.request(request) }
    raise Error, "CloudFront invalidation request failed (HTTP #{response.code})" unless response.is_a?(Net::HTTPSuccess)
    response
  rescue SocketError, IOError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, Net::HTTPBadResponse => error
    raise Error, "CloudFront transport failed (#{error.class})"
  rescue Aws::Errors::MissingCredentialsError, Aws::Sigv4::Errors::MissingCredentialsError
    raise Error, "CloudFront credentials are unavailable"
  end
end
