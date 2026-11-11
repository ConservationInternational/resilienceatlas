class LayerDataSources
  def self.cog_urls(layer)
    config = JSON.parse(layer.layer_config.presence || "{}")
    body = config.fetch("body", config)
    sources = Array(body["sources"]) + Array(body["source"])
    if body["url"].present?
      sources += URI.decode_www_form(body["url"].split("?", 2).last.to_s).to_h.slice("url").values
    end
    sources.select { |source| source.is_a?(String) }
  end

  def self.matches?(template, requested)
    pattern = Regexp.escape(template)
      .gsub(Regexp.escape("{{year}}"), "[0-9]{4}")
      .gsub(Regexp.escape("{{month}}"), "(?:0[1-9]|1[0-2])")
      .gsub(Regexp.escape("{{day}}"), "(?:0[1-9]|[12][0-9]|3[01])")
    /\A#{pattern}\z/.match?(requested)
  end
end
