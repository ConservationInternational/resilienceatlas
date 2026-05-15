class ScopeDatasetSerializer < ActiveModel::Serializer
  attributes :id, :slug, :name, :description, :data_type, :group_key,
    :variant_label, :dimension, :dimension_config, :schema_config,
    :chart_config, :display_order, :row_count, :geometry_count

  belongs_to :site_scope, serializer: ScopeDatasetSiteScopeSerializer

  def row_count
    object.row_count
  end

  def geometry_count
    if object.has_attribute?(:geom_count_cache)
      object.geom_count_cache.to_i
    else
      object.geometry_count
    end
  end
end
