class TileSourceGeneration < ApplicationRecord
  validates :source_key, :data_version, :policy_version, presence: true
  validates :source_key, uniqueness: true
end
