# frozen_string_literal: true

class Api::Admin::LayersController < Api::Admin::ApiController
  before_action :load_layer, only: %i[update destroy show]
  include Api::Pagination

  def index
    @layers = Layer.order("created_at DESC")
    @layers = @layers.paginate page: page, per_page: per_page
    render json: {success: true, message: "List of all Layers", data: @layers.as_json(except: [:timeline_format]), meta_attributes: meta_attributes(@layers)},
      status: :ok
  end

  def create
    Layer.transaction do
      @layer = Layer.create!(layer_params)
      Api::Admin::LayersManager.new(@layer, params[:site_scope_id]).link_layer_group if params[:site_scope_id].present?
      render json: {success: true, message: "Layer Created Successfully", data: @layer.as_json(except: [:timeline_format])}, status: :ok
    end
  end

  def destroy
    @layer.destroy!
    render json: {success: true, message: "Layer Deleted Successfully", data: @layer.as_json(except: [:timeline_format])}, status: :ok
  end

  def update
    Layer.transaction do
      puts layer_params.inspect
      @layer.update!(layer_params)
      Api::Admin::LayersManager.new(@layer, params[:site_scope_id]).link_layer_group if params[:site_scope_id].present?
      render json: {success: true, message: "Layer Updated Successfully", data: @layer.as_json(except: [:timeline_format])}, status: :ok
    end
  end

  def show
    render json: {success: true, message: "Layer Details", data: @layer.as_json(except: [:timeline_format])}, status: :ok
  end

  def site_scopes
    @site_scopes = SiteScope.where(site_scope_translations: {locale: I18n.locale}).order(name: :asc)
    @site_scopes = @site_scopes.ransack(translations_name_i_cont: params[:keyword]).result if params[:keyword].present?
    render json: {success: true, message: "List of all Site Scopes", data: @site_scopes.as_json}, status: :ok
  end

  private

  def layer_params
    params.require(:layer).permit(Layer::WHITELIST_ATTRIBUTES)
  end

  def load_layer
    @layer = Layer.find params[:id]
  end

  def per_page
    params.fetch(:per_page, 30)
  end

  def page
    params.fetch(:page, 1)
  end
end
