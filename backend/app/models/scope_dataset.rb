class ScopeDataset < ApplicationRecord
  belongs_to :site_scope
  has_many :scope_dataset_geometries, dependent: :destroy

  validates :slug, presence: true,
    uniqueness: {scope: :site_scope_id},
    format: {with: /\A[a-zA-Z0-9]+(?:[-_][a-zA-Z0-9]+)*\z/, message: "must be alphanumeric with hyphens or underscores"}
  validates :name, presence: true
  validates :data_type, presence: true, inclusion: {in: %w[tabular]}
  validates :data, presence: true
  validates :schema_config, presence: true

  scope :for_site_scope, ->(site_scope_id) { where(site_scope_id: site_scope_id) }
  scope :for_group, ->(group_key) { where(group_key: group_key) }
  scope :for_dimension, ->(dimension) { where(dimension: dimension) }
  scope :ordered, -> { order(:display_order, :name) }

  def row_count
    data.is_a?(Array) ? data.size : 0
  end

  def geometry_count
    scope_dataset_geometries.count
  end

  def self.ransackable_attributes(auth_object = nil)
    %w[id slug name data_type group_key variant_label dimension site_scope_id display_order created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[site_scope scope_dataset_geometries]
  end
end
