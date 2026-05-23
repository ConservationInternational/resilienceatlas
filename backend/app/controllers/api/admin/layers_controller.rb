# frozen_string_literal: true

class Api::Admin::LayersController < Api::Admin::ApiController
  before_action :load_layer, only: %i[update destroy show]
  include Api::Pagination

  def index
    @layers = Layer.order("created_at DESC")
    if params[:site_scope_id].present?
      @layers = @layers.joins(layer_groups: :site_scopes)
        .where(site_scopes: {id: params[:site_scope_id]})
        .distinct
    end
    if params[:keyword].present?
      kw = "%#{params[:keyword].downcase}%"
      @layers = @layers.joins(:translations)
        .where(layer_translations: {locale: I18n.default_locale})
        .where(
          "LOWER(layer_translations.name) LIKE :kw OR LOWER(layer_translations.title) LIKE :kw OR LOWER(layer_translations.description) LIKE :kw OR LOWER(layers.slug) LIKE :kw OR LOWER(layers.dataset_shortname) LIKE :kw OR LOWER(layers.layer_config::text) LIKE :kw",
          kw: kw
        )
    end
    @layers = @layers.paginate page: page, per_page: per_page
    render json: {success: true, message: "List of all Layers", data: @layers.as_json, meta_attributes: meta_attributes(@layers)},
      status: :ok
  end

  def create
    Layer.transaction do
      @layer = Layer.create!(layer_params)
      link_layer_group_assignment if layer_group_assignment_requested?
      render json: {success: true, message: "Layer Created Successfully", data: @layer.as_json}, status: :ok
    end
  end

  def destroy
    @layer.destroy!
    render json: {success: true, message: "Layer Deleted Successfully", data: @layer.as_json}, status: :ok
  end

  def update
    Layer.transaction do
      @layer.update!(layer_params)
      link_layer_group_assignment if layer_group_assignment_requested?
      render json: {success: true, message: "Layer Updated Successfully", data: @layer.as_json}, status: :ok
    end
  end

  def show
    # Include site_scope_ids so the Bedrock agent Lambda can enforce per-scope
    # authorization. Layer uses a many-to-many via layer_groups (no direct column).
    scope_ids = @layer.site_scopes.pluck(:id).map(&:to_s)
    render json: {success: true, message: "Layer Details", data: @layer.as_json.merge("site_scope_ids" => scope_ids)}, status: :ok
  end

  def site_scopes
    @site_scopes = SiteScope.with_translations(I18n.locale).order(:id)
    if params[:keyword].present?
      @site_scopes = @site_scopes.ransack(translations_name_or_subdomain_i_cont: params[:keyword]).result
    end

    site_scopes = @site_scopes.to_a.sort_by do |site_scope|
      [site_scope.name.to_s.downcase, site_scope.subdomain.to_s.downcase, site_scope.id]
    end

    render json: {success: true, message: "List of all Site Scopes", data: site_scopes.as_json}, status: :ok
  end

  private

  def layer_params
    params.require(:layer).permit(Layer::WHITELIST_ATTRIBUTES)
  end

  def load_layer
    @layer = Layer.find params[:id]
  end

  def per_page
    params.fetch(:per_page, 200)
  end

  def page
    params.fetch(:page, 1)
  end

  def layer_group_assignment_requested?
    params[:site_scope_id].present? || requested_layer_group_id.present?
  end

  def link_layer_group_assignment
    Api::Admin::LayersManager.new(
      @layer,
      params[:site_scope_id],
      layer_group_id: requested_layer_group_id
    ).link_layer_group
  end

  def requested_layer_group_id
    params[:layer_group_id].presence || params.dig(:layer, :layer_group_id).presence
  end
end
