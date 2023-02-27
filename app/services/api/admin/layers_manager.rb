class Api::Admin::LayersManager
  def initialize(layer, site_scope_id)
    @layer = layer
    @site_scope_id = site_scope_id
  end

  def link_layer_group
    return if layer.blank? || site_scope_id.blank?

    link
  end

  private

  attr_accessor :layer, :site_scope_id

  def link
    site_scope = SiteScope.find_by(id: site_scope_id)
    return if site_scope.blank?

    layer_group = site_scope.layer_groups.find_or_create_by!(name: "New uploads")
    layer_group.agrupations.find_or_create_by!(layer_id: layer.id)
  end
end
