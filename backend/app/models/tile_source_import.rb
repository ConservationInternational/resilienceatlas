class TileSourceImport < ApplicationRecord
  BLOCKING_STATUSES = %w[staged invalidation_pending writing validating reconciliation_required failed].freeze
  validates :run_id, :identity, :operation, :fingerprint, presence: true
  validates :status, inclusion: {in: BLOCKING_STATUSES + ["completed"]}
  scope :blocking, -> { where.not(status: "completed") }

  def blocks?(layer, key)
    global? || layer_ids.include?(layer.id) || (key.present? && source_keys.include?(key))
  end

  def self.latest_for(layer)
    key = TileSecurityPolicy.new(layer).source_key
    where("global = TRUE OR layer_ids @> ?::jsonb OR source_keys @> ?::jsonb",
      [layer.id].to_json, key ? [key].to_json : '["unresolved-source"]')
      .order(created_at: :desc, id: :desc).first
  end

  def safe_status
    {"id" => id, "run_id" => run_id, "status" => status, "in_place" => in_place,
     "created_at" => created_at&.iso8601, "completed_at" => completed_at&.iso8601,
     "writer_completed" => summary["writer_completed"] == true,
     "invalidation_ids" => invalidation_ids}
  end
end
