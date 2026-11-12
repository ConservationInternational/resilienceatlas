require "digest"
require "socket"

class TileSourceLifecycle
  class InvalidationPending < StandardError; end

  class ImportBlocked < StandardError; end

  attr_reader :record

  def self.operator_identity
    ENV["TILE_IMPORT_IDENTITY"].presence || "system:#{Socket.gethostname}:uid-#{Process.uid}"
  end

  def self.run!(operation:, fingerprint:, layers: Layer.all, identity: operator_identity, in_place: true, global: false, dry_run: false, &block)
    lifecycle = new(operation: operation, fingerprint: fingerprint, layers: layers,
      identity: identity, in_place: in_place, global: global)
    return lifecycle.plan if dry_run
    lifecycle.run!(&block)
  end

  def self.run_task!(operation, &block)
    fingerprint = ENV["TILE_IMPORT_FINGERPRINT"]
    raise ArgumentError, "Set TILE_IMPORT_FINGERPRINT to the input manifest/content SHA256 (including view dependencies)" if fingerprint.blank?
    result = run!(operation: operation, fingerprint: fingerprint, global: true,
      dry_run: ENV["TILE_IMPORT_DRY_RUN"] == "1", &block)
    puts JSON.generate(result)
    result
  end

  def self.authorize_enclosing_import!
    record = TileSourceImport.find_by!(run_id: ENV.fetch("TILE_IMPORT_RUN_ID"))
    unless record.global? && record.status == "writing" && record.identity == operator_identity
      raise ImportBlocked, "The enclosing import is not writable by this identity"
    end
    record
  end

  def self.seed!(path)
    if ENV["TILE_IMPORT_RUN_ID"].present?
      authorize_enclosing_import!
      yield
    else
      run_task!("seed:#{File.basename(File.dirname(path))}") { yield }
    end
  end

  def initialize(operation:, fingerprint:, layers:, identity:, in_place: true, global: false)
    raise ArgumentError, "Import operation, fingerprint and operator identity are required" if [operation, fingerprint, identity].any?(&:blank?)
    @operation, @fingerprint, @identity = operation, fingerprint, identity
    initial = layers.to_a
    @layers = (initial + initial.flat_map { |layer| TileSecurityPolicy.new(layer).aliases.to_a }).uniq(&:id)
    @global, @in_place = global, in_place
  end

  def plan
    {"operation" => @operation, "fingerprint" => @fingerprint, "identity" => @identity,
     "layer_ids" => @layers.map(&:id), "source_keys" => @layers.filter_map { |layer| TileSecurityPolicy.new(layer).source_key }.uniq,
     "in_place" => @in_place, "global" => @global, "dry_run" => true,
     "evidence" => "local_configuration_only", "publication_changed" => false}
  end

  def stage!
    TileSourceImport.transaction do
      # Serialize acquisition, not the external writes. The durable blocking row
      # remains visible while data loaders and CDN operators run outside SQL.
      TileSourceImport.connection.execute("SELECT pg_advisory_xact_lock(827341902)")
      last = TileSourceImport.where(operation: @operation).order(id: :desc).first
      unchanged = last&.status != "completed" ||
        TileSourceGeneration.where(source_key: last&.source_keys || []).where.not(fingerprint: @fingerprint).none?
      if last&.fingerprint == @fingerprint && unchanged
        raise ImportBlocked, "Resume using the recorded import identity" if last.identity != @identity
        @record = last
        return @record
      end
      if TileSourceImport.blocking.any? { |run| @global || run.global? || (run.layer_ids & @layers.map(&:id)).any? || (run.source_keys & plan["source_keys"]).any? }
        raise ImportBlocked, "An overlapping import requires reconciliation before another run"
      end
      pending_layer_ids = if defined?(TileCacheInvalidation) && TileCacheInvalidation.table_exists?
        TileCacheInvalidation.where(layer_id: @layers.map(&:id)).where.not(status: "completed").distinct.pluck(:layer_id)
      else
        []
      end
      public_layers = @layers.select do |layer|
        layer.public_data? || TileSecurityPolicy.new(layer).public_cache_eligible? ||
          (layer.published? && pending_layer_ids.include?(layer.id))
      end
      @record = TileSourceImport.create!(run_id: SecureRandom.uuid, operation: @operation, identity: @identity,
        fingerprint: @fingerprint, in_place: @in_place, global: @global,
        layer_ids: @layers.map(&:id), source_keys: plan["source_keys"],
        summary: plan.except("dry_run").merge("cached_layer_ids" => public_layers.map(&:id),
          "previous_versions" => @layers.to_h { |layer| [layer.id.to_s, layer.tile_cache_version] }))
      if public_layers.any?
        unless defined?(TileCacheInvalidation) && TileCacheInvalidation.table_exists?
          @record.update!(status: "invalidation_pending", error_message: "Cache invalidation storage is unavailable")
          return @record
        end
        ids = public_layers.map do |layer|
          TileCacheInvalidation.create!(layer_id: layer.id, status: "pending",
            paths: TilePolicyLifecycle.invalidation_paths(layer)).id
        end
        @record.update!(invalidation_ids: ids, status: "invalidation_pending")
      end
      @record
    end
  end

  def ready_to_write!
    raise ImportBlocked, "Stage the import first" unless @record
    @record.with_lock do
      return if @record.status == "completed"
      raise ImportBlocked, "This import already has an active writer" if @record.status == "writing"
      if @record.in_place? && @record.summary.fetch("cached_layer_ids", []).any?
        ids = @record.invalidation_ids
        confirmed = ids.any? && defined?(TileCacheInvalidation) && TileCacheInvalidation.table_exists? &&
          TileCacheInvalidation.where(id: ids, status: "completed").count == ids.size
        raise InvalidationPending, "Import #{@record.run_id} is blocked until every public cache invalidation is confirmed completed" unless confirmed
      end
      @record.update!(status: "writing", error_message: nil, summary: @record.summary.merge("writer_completed" => false))
      @writer_claimed = true
    end
  end

  def run!
    @writer_claimed = false
    stage!
    return @record.summary.merge("unchanged" => true, "run_id" => @record.run_id) if @record.status == "completed"
    ready_to_write!
    result = yield @record if block_given?
    if result.is_a?(Layer)
      @record.update!(layer_ids: (@record.layer_ids + [result.id]).uniq)
    end
    @record.update!(status: "validating", summary: @record.summary.merge("writer_completed" => true))
    reconcile!
  rescue InvalidationPending
    raise
  rescue StandardError, SystemExit => error
    # SystemExit from legacy rake tasks must not turn a partial write into success.
    @record.update!(status: "reconciliation_required", error_message: error.class.name) if @writer_claimed && @record.status != "completed"
    raise
  end

  def reconcile!
    raise ImportBlocked, "The import writer has not completed; resume the writer first" unless @record.summary["writer_completed"]
    @record.update!(status: "validating")
    affected = @record.global? ? Layer.all : Layer.where(id: @record.layer_ids)
    affected.find_each do |layer|
      next unless layer.published? && TileSecurityPolicy::SUPPORTED_PROVIDERS.include?(layer.layer_provider)
      raise ImportBlocked, "A published source could not be resolved (layer #{layer.id})" unless TileSecurityPolicy.new(layer).source_key
      next unless @record.in_place? && layer.layer_provider == "martin"
      config = JSON.parse(layer.layer_config)
      table = config.dig("body", "params", "table") || config.dig("body", "source") || config["source"]
      exists = Layer.connection.select_value("SELECT to_regclass(#{Layer.connection.quote("ra_vector.#{table}")})")
      raise ImportBlocked, "An imported vector source is absent (layer #{layer.id})" unless exists
    end
    TileSourceImport.transaction do
      # Finish within the same transaction as the generation/approval updates.
      # Rollback leaves the durable source block in place.
      @record.update!(status: "completed", completed_at: Time.current, error_message: nil)
      TilePolicyLifecycle.refresh!(affected.to_a, reason: "source_import_activated", data_changed: true, fingerprint: @record.fingerprint)
      generations = TileSourceGeneration.where(source_key: affected.filter_map { |layer| TileSecurityPolicy.new(layer).source_key })
        .pluck(:source_key, :data_version, :policy_version).map { |key, data, policy| {"source_key" => key, "data_version" => data, "policy_version" => policy} }
      summary = @record.summary.merge("run_id" => @record.run_id, "status" => "completed",
        "versions" => affected.pluck(:id, :tile_cache_version).to_h.transform_keys(&:to_s),
        "generations" => generations, "invalidation_ids" => @record.invalidation_ids,
        "verification" => @record.in_place? ? "configuration_and_local_source_presence" : "verified_immutable_upload")
      @record.update!(summary: summary, layer_ids: affected.pluck(:id),
        source_keys: generations.map { |generation| generation["source_key"] }.uniq)
      summary
    end
  rescue => error
    if @record.summary["writer_completed"]
      @record.update!(status: "reconciliation_required", error_message: error.class.name)
    end
    raise
  end

  def self.resume(record)
    lifecycle = new(operation: record.operation, fingerprint: record.fingerprint,
      identity: record.identity, layers: Layer.where(id: record.layer_ids), in_place: record.in_place, global: record.global)
    lifecycle.instance_variable_set(:@record, record)
    lifecycle
  end
end
