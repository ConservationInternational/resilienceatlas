class ScopeDatasetGeometry < ApplicationRecord
  belongs_to :scope_dataset

  validates :unit_id, presence: true, uniqueness: {scope: :scope_dataset_id}
  validates :geom, presence: true

  def self.ransackable_attributes(auth_object = nil)
    %w[id unit_id scope_dataset_id created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[scope_dataset]
  end
end
