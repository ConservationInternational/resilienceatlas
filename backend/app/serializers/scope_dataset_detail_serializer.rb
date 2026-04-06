class ScopeDatasetDetailSerializer < ActiveModel::Serializer
  attributes :id, :slug, :name, :description, :data_type, :group_key,
    :variant_label, :dimension, :dimension_config, :schema_config,
    :data, :chart_config, :display_order, :row_count, :geometry_count

  belongs_to :site_scope, serializer: ScopeDatasetSiteScopeSerializer

  def row_count
    object.row_count
  end

  def geometry_count
    object.geometry_count
  end
end
