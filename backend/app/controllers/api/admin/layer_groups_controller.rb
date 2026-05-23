# frozen_string_literal: true

class Api::Admin::LayerGroupsController < Api::Admin::ApiController
  # GET /api/admin/layer_groups?site_scope_id=1
  def index
    layer_groups = LayerGroup.includes(:layers, :super_group).order(:order, :name)
    layer_groups = layer_groups.where(site_scope_id: params[:site_scope_id]) if params[:site_scope_id].present?
    layer_groups = layer_groups.where(super_group_id: params[:super_group_id]) if params[:super_group_id].present?
    layer_groups = layer_groups.where(layer_group_type: params[:layer_group_type]) if params[:layer_group_type].present?

    if params[:keyword].present?
      keyword = "%#{params[:keyword].to_s.downcase}%"
      layer_groups = layer_groups.where(
        "LOWER(layer_groups.name) LIKE :keyword OR LOWER(COALESCE(layer_groups.slug, '')) LIKE :keyword",
        keyword: keyword
      )
    end

    render json: {
      success: true,
      message: "List of Layer Groups",
      data: serialize_layer_groups(layer_groups)
    }, status: :ok
  end

  # POST /api/admin/layer_groups
  def create
    attrs = layer_group_params.to_h.symbolize_keys
    attrs[:slug] = normalize_slug(attrs[:slug], attrs[:name])
    attrs[:layer_group_type] ||= "category"
    attrs[:active] = true if attrs[:active].nil?

    layer_group = LayerGroup.find_or_initialize_by(site_scope_id: attrs[:site_scope_id], slug: attrs[:slug])
    layer_group.assign_attributes(attrs.except(:site_scope_id, :slug))
    layer_group.site_scope_id = attrs[:site_scope_id]
    layer_group.slug = attrs[:slug]
    layer_group.save!

    render json: {
      success: true,
      message: "Layer Group Created Successfully",
      data: serialize_layer_group(layer_group)
    }, status: :ok
  end

  private

  def layer_group_params
    params.require(:layer_group).permit(
      :site_scope_id,
      :name,
      :slug,
      :layer_group_type,
      :super_group_id,
      :category,
      :active,
      :order,
      :info,
      :icon_class
    )
  end

  def normalize_slug(slug, name)
    value = slug.presence || name
    normalized = value.to_s.parameterize
    raise ActionController::ParameterMissing, "layer_group.slug" if normalized.blank?

    normalized
  end

  def serialize_layer_groups(layer_groups)
    layer_groups.map { |layer_group| serialize_layer_group(layer_group) }
  end

  def serialize_layer_group(layer_group)
    {
      id: layer_group.id,
      name: layer_group.name,
      slug: layer_group.slug,
      site_scope_id: layer_group.site_scope_id,
      super_group_id: layer_group.super_group_id,
      super_group_name: layer_group.super_group&.name,
      layer_group_type: layer_group.layer_group_type,
      category: layer_group.category,
      active: layer_group.active,
      order: layer_group.order,
      icon_class: layer_group.icon_class,
      layers_count: layer_group.layers.size
    }
  end
end