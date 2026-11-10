class SpatialUploadLifecycle
  EXTENSIONS = {"vector" => %w[.gpkg .geojson .json .zip], "cog" => %w[.tif .tiff]}.freeze
  CONFIG_KEYS = %w[name slug source_crs sublayer raster_kind bidx rescale nodata colormap_name color legend popup_fields colormap replace_style].freeze

  def self.max_bytes
    Integer(ENV.fetch("UPLOAD_MAX_BYTES", 5.gigabytes.to_s))
  end

  def self.create!(user, attributes)
    type = attributes.fetch("import_type")
    filename = File.basename(attributes.fetch("file_name").delete("\x00"))
    raise ArgumentError, "Unsupported file format" unless EXTENSIONS.fetch(type, []).include?(File.extname(filename).downcase)
    size = Integer(attributes.fetch("file_size_bytes"))
    raise ArgumentError, "File size must be between 1 byte and #{max_bytes} bytes" unless size.between?(1, max_bytes)
    if File.extname(filename).downcase == ".zip" && size > VectorUploadProcessor::MAX_ARCHIVE_BYTES
      raise ArgumentError, "ZIP upload exceeds the compressed archive limit"
    end
    mode = attributes.fetch("mode", "create")
    raise ArgumentError, "Invalid upload mode" unless %w[create replace dataset].include?(mode)
    target = (mode == "replace") ? Layer.find(attributes.fetch("layer_id")) : nil
    ability = Ability.new(user)
    raise CanCan::AccessDenied unless ability.can?(:manage, DataImport)
    raise CanCan::AccessDenied if target && !ability.can?(:update, target)
    record = DataImport.new(admin_user: user, importable: target, import_type: type, status: "uploading",
      file_name: filename, file_size_bytes: size, target_updated_at: target&.updated_at,
      options: {"workflow" => "spatial_upload", "mode" => mode}.merge(attributes.slice(*CONFIG_KEYS)),
      stage: "Waiting for file transfer")
    new(record).validate_configuration!(record.options)
    record.save!
    record
  end

  def initialize(di)
    @di = di
  end

  def enqueue!
    @di.with_lock do
      return if @di.pending? || @di.processing? || @di.ready? || @di.complete?
      raise ArgumentError, "This upload cannot be queued" unless @di.uploading? || @di.failed? || @di.needs_input?
      object = UploadStorage.new.head(@di.s3_key)
      raise ArgumentError, "Stored file size does not match" unless object.content_length == @di.file_size_bytes
      @di.update!(status: "pending", stage: "Queued", error_message: nil, metadata: @di.metadata.except("verified"))
    end
    job_id = SpatialUploadJob.perform_async(@di.id)
    raise "The import worker did not accept the job" if job_id.blank?
    @di.update!(job_id: job_id)
  rescue => e
    @di.update!(status: "failed", stage: "Queue failed", error_message: e.message) unless @di.processing? || @di.cancelled?
    Rails.logger.error "[Upload #{@di.id}] Queue failed: #{e.message}"
    raise
  end

  def configure!(values)
    @di.with_lock do
      raise ArgumentError, "Wait until processing finishes" unless @di.ready? || @di.needs_input? || @di.failed?
      options = @di.options.merge(values.slice(*CONFIG_KEYS))
      validate_configuration!(options)
      reprocess = %w[source_crs sublayer raster_kind].any? { |key| options[key].to_s != @di.options[key].to_s }
      @di.update!(options: options, metadata: @di.metadata.except("verified"),
        status: (reprocess && @di.ready?) ? "needs_input" : @di.status)
    end
  end

  def finalize!
    @di.with_lock do
      return @di.importable if @di.complete?
      raise ArgumentError, "Process and verify the preview first" unless @di.ready? && @di.metadata["verified"]
      validate_configuration!(@di.options)
      if @di.options["mode"] == "dataset"
        @di.update!(status: "complete", stage: "Dataset ready", completed_at: Time.current)
        return nil
      end
      attributes = UploadLayerConfiguration.new(@di).attributes
      layer = @di.importable
      if layer
        layer.with_lock do
          raise ArgumentError, "The layer changed since this upload began. Start a new replacement." unless layer.updated_at == @di.target_updated_at
          previous = UploadLayerConfiguration.snapshot(layer)
          # Source-dependent analysis must be revalidated for the replacement.
          layer.update!(attributes.merge(analysis_suitable: false))
          @di.update!(previous_configuration: previous, target_updated_at: layer.updated_at)
        end
      else
        layer = Layer.create!(attributes.merge(name: @di.options.fetch("name"), slug: @di.options.fetch("slug"),
          published: false, timeline: false, analysis_suitable: false, opacity: 1))
      end
      @di.update!(importable: layer, status: "complete", stage: "Layer saved", completed_at: Time.current)
      DatasetInventoryService.invalidate_all_caches!
      layer
    end
  end

  def rollback!
    @di.with_lock do
      raise ArgumentError, "No replacement is available to roll back" unless @di.complete? && @di.previous_configuration.present? && @di.importable.is_a?(Layer)
      layer = @di.importable
      layer.with_lock do
        raise ArgumentError, "The layer changed after this replacement" unless layer.updated_at == @di.target_updated_at
        layer.update!(@di.previous_configuration)
      end
      @di.update!(stage: "Rolled back", previous_configuration: {})
      DatasetInventoryService.invalidate_all_caches!
    end
  end

  def validate_configuration!(options)
    if options["mode"] == "create"
      raise ArgumentError, "Layer name and slug are required" if options["name"].blank? || options["slug"].blank?
      raise ArgumentError, "Invalid layer slug" unless options["slug"].match?(/\A[a-zA-Z0-9]+(?:[-_][a-zA-Z0-9]+)*\z/)
    end
    if options["source_crs"].present? && !options["source_crs"].match?(/\AEPSG:\d{3,6}\z/i)
      raise ArgumentError, "Specify the source CRS as EPSG:<number>"
    end
    if options["raster_kind"].present? && !%w[continuous categorical rgb].include?(options["raster_kind"])
      raise ArgumentError, "Invalid raster display type"
    end
    if options["bidx"].present?
      bands = options["bidx"].to_s.split(",").map { |band| Integer(band) }
      count = Array(@di.metadata["bands"]).size
      raise ArgumentError, "Choose one band or three RGB bands" unless [1, 3].include?(bands.size)
      raise ArgumentError, "Band index is out of range" unless bands.all? { |band| band.positive? && (count.zero? || band <= count) }
    end
    if options["rescale"].present?
      range = options["rescale"].to_s.split(",").map { |value| Float(value) }
      raise ArgumentError, "Rescale must be two finite ascending values" unless range.size == 2 && range.all?(&:finite?) && range[0] < range[1]
    end
    if options["nodata"].present?
      raise ArgumentError, "Nodata must be numeric" unless Float(options["nodata"]).finite?
    end
    if options["color"].present? && !options["color"].match?(/\A#[0-9a-f]{6}\z/i)
      raise ArgumentError, "Invalid color"
    end
    JSON.parse(options["legend"]) if options["legend"].present?
    if options["colormap"].present?
      raise ArgumentError, "Colormap must be an object or array" unless options["colormap"].is_a?(Hash) || options["colormap"].is_a?(Array)
    end
    if @di.ready? && @di.type_vector? && options.key?("popup_fields")
      unknown = Array(options["popup_fields"]) - Array(@di.metadata["fields"])
      raise ArgumentError, "Unknown popup fields: #{unknown.join(", ")}" if unknown.any?
    end
    layer = @di.importable
    if @di.ready? && @di.type_vector? && layer.is_a?(Layer) && layer.layer_provider == "martin" && options["replace_style"] != true
      property = JSON.parse(layer.layer_config.presence || "{}").dig("body", "colorRamp", "property")
      if property.present? && !Array(@di.metadata["fields"]).include?(property)
        raise ArgumentError, "Existing color ramp requires missing field '#{property}'. Select Replace existing vector styling before previewing."
      end
    end
  end
end
