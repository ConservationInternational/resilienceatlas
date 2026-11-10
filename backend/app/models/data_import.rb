class DataImport < ApplicationRecord
  belongs_to :importable, polymorphic: true, optional: true
  belongs_to :admin_user

  enum :status, {
    pending: "pending",
    processing: "processing",
    complete: "complete",
    failed: "failed",
    uploading: "uploading",
    needs_input: "needs_input",
    ready: "ready",
    cancelled: "cancelled"
  }

  enum :import_type, {
    cog: "cog",
    vector: "vector",
    csv: "csv"
  }, prefix: :type

  validates :import_type, presence: true
  validates :status, presence: true

  def managed_upload?
    options["workflow"] == "spatial_upload"
  end

  def duration
    return nil unless started_at && completed_at
    completed_at - started_at
  end

  def formatted_file_size
    return "—" unless file_size_bytes
    if file_size_bytes >= 1.gigabyte
      "#{(file_size_bytes.to_f / 1.gigabyte).round(2)} GB"
    elsif file_size_bytes >= 1.megabyte
      "#{(file_size_bytes.to_f / 1.megabyte).round(1)} MB"
    else
      "#{(file_size_bytes.to_f / 1.kilobyte).round(1)} KB"
    end
  end

  def self.ransackable_attributes(auth_object = nil)
    %w[id status import_type file_name admin_user_id importable_type importable_id created_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[importable admin_user]
  end
end
