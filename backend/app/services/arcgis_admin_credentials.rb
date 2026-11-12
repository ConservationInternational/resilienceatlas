class ArcgisAdminCredentials
  def self.apply(layer, replacement:, clear:)
    return unless layer.layer_provider == "arcgis_feature"
    config = JSON.parse(layer.layer_config.presence || "{}")
    body = config["body"]
    raise ArgumentError, "ArcGIS configuration requires a body object" unless body.is_a?(Hash)
    previous = JSON.parse(layer.attribute_in_database("layer_config").presence || "{}")
    old_body = previous["body"].is_a?(Hash) ? previous["body"] : {}
    body.delete("useProxy")
    if clear
      body.delete("token")
    elsif replacement.present?
      body["token"] = replacement
    elsif old_body["url"] == body["url"] && old_body["token"].present?
      body["token"] = old_body["token"]
    end
    layer.layer_config = config.to_json
  rescue JSON::ParserError
    raise ArgumentError, "ArcGIS configuration must be valid JSON"
  end
end
