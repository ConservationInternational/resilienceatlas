class Api::Admin::LayersManager
  def initialize(layer, site_scope_id = nil, layer_group_id: nil)
    @layer = layer
    @site_scope_id = site_scope_id
    @layer_group_id = layer_group_id
  end

  def link_layer_group
    return if layer.blank?

    target_layer_group = resolve_layer_group
    return if target_layer_group.blank?

    target_layer_group.agrupations.find_or_create_by!(layer_id: layer.id)
  end

  private

  attr_accessor :layer, :site_scope_id, :layer_group_id

  def resolve_layer_group
    return explicit_layer_group if layer_group_id.present?

    default_layer_group
  end

  def explicit_layer_group
    return if layer_group_id.blank?

    layer_group = LayerGroup.find_by(id: layer_group_id)
    return if layer_group.blank?
    return if site_scope_id.present? && layer_group.site_scope_id != site_scope_id.to_i

    layer_group
  end

  def default_layer_group
    site_scope = resolve_site_scope
    return if site_scope.blank?

    site_scope.layer_groups.find_or_create_by!(name: "New uploads") do |layer_group|
      layer_group.slug = "new-uploads"
      layer_group.layer_group_type = "group"
      layer_group.active = true
    end
  end

  def resolve_site_scope
    return SiteScope.find_by(id: site_scope_id) if site_scope_id.present?

    LayerGroup.find_by(id: layer_group_id)&.site_scope
  end
end
