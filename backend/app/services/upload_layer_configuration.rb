class UploadLayerConfiguration
  def initialize(data_import)
    @di = data_import
  end

  def attributes
    config = compatible_config
    body = config.fetch("body", {}).except("source", "sources", "url", "params", "clip_geometry")
    if @di.type_vector?
      table = @di.metadata.fetch("table")
      old_table = config.dig("body", "params", "table") || config.dig("body", "source")
      styles = body["styles"] || {}
      inherited_style = styles[old_table] || styles["default"]
      body["styles"] = {table => inherited_style} if inherited_style
      body["source"] = "ra_vector_tile"
      body["params"] = {"table" => table}
      if body["styles"].blank? || @di.options["replace_style"] == true
        body.delete("colorRamp") if @di.options["replace_style"]
        body["styles"] = {table => {"fillColor" => @di.options.fetch("color", "#3388ff"),
                                    "fillOpacity" => 0.6, "color" => @di.options.fetch("color", "#3388ff"), "weight" => 2, "radius" => 5}}
      end
      interaction = @di.metadata["interaction_config"] || {"output" => []}
      if @di.importable.is_a?(Layer) && @di.importable.layer_provider == "martin"
        previous = JSON.parse(@di.importable.interaction_config)
        available = interaction.fetch("output", []).map { |field| field["column"] }
        interaction = interaction.merge("output" => previous.fetch("output", []).select { |field| available.include?(field["column"]) })
        interaction["enabled"] = previous["enabled"] if previous.key?("enabled")
      end
      if @di.options.key?("popup_fields")
        selected = Array(@di.options["popup_fields"])
        interaction = interaction.merge("output" => interaction.fetch("output", []).select { |field| selected.include?(field["column"]) })
      end
    else
      body["source"] = @di.metadata.fetch("source")
      %w[bidx rescale nodata colormap_name colormap].each do |key|
        next unless @di.options.key?(key)
        if @di.options[key].present?
          body[key] = @di.options[key]
        else
          body.delete(key)
        end
      end
      body["bidx"] ||= 1
      body["resampling_method"] = (@di.options["raster_kind"] == "categorical") ? "nearest" : "bilinear"
      interaction = LayerInteractionConfigBuilder.for_cog.deep_dup
      bands = body["bidx"].to_s.split(",").map { |value| Integer(value) }
      interaction["output"] = bands.each_with_index.map do |band, index|
        {"column" => "values.#{index}", "property" => "Band #{band}", "type" => "number"}
      end
      indices = bands.map { |band| "bidx[]=#{band}" }.join("&")
      interaction["config"]["url"] = "/api/titiler/point?titilerUrl={{titilerUrl}}&cogUrl={{cogUrl}}&lon={{lng}}&lat={{lat}}&#{indices}"
    end
    result = {layer_provider: @di.type_vector? ? "martin" : "cog",
              layer_config: config.merge("body" => body).to_json, interaction_config: interaction.to_json}
    result[:legend] = @di.options["legend"] if @di.options.key?("legend")
    result
  end

  def self.snapshot(layer)
    layer.attributes.slice("layer_provider", "layer_config", "interaction_config", "legend",
      "analysis_suitable", "analysis_query", "analysis_body", "analysis_type")
  end

  private

  def compatible_config
    layer = @di.importable
    return {} unless layer.is_a?(Layer) && layer.layer_provider == (@di.type_vector? ? "martin" : "cog")
    JSON.parse(layer.layer_config.presence || "{}")
  end
end
