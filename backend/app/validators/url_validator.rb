class UrlValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return unless value.present?
    return if url_valid?(value)

    message = options[:message] || "must be a valid URL"
    record.errors.add(attribute, :url, message: message, value: value)
  end

  def url_valid?(url)
    url = begin
      URI.parse(url)
    rescue
      false
    end
    url.is_a?(URI::HTTP) || url.is_a?(URI::HTTPS)
  end
end
