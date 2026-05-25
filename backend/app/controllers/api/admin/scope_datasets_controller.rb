# frozen_string_literal: true

class Api::Admin::ScopeDatasetsController < Api::Admin::ApiController
  before_action :load_scope_dataset, only: %i[show update]

  # GET /api/admin/scope_datasets?site_scope_id=1
  def index
    scope = ScopeDataset.all
    scope = scope.for_site_scope(params[:site_scope_id]) if params[:site_scope_id].present?
    scope = scope.ordered
    # Omit the large :data column in list view — use show for full record
    per_page = params[:per_page].to_i.clamp(1, 500).nonzero? || 100
    records = scope.select(
      :id, :site_scope_id, :slug, :name, :description, :data_type,
      :group_key, :variant_label, :dimension, :dimension_config,
      :schema_config, :chart_config, :display_order, :created_at, :updated_at
    ).paginate(page: params[:page].presence || 1, per_page: per_page)
    render json: {
      success: true,
      message: "List of Scope Datasets",
      data: records.as_json,
      meta: {current_page: records.current_page, total_pages: records.total_pages, total_entries: records.total_entries}
    }, status: :ok
  end

  # GET /api/admin/scope_datasets/:id
  def show
    render json: {success: true, message: "Scope Dataset Details", data: @scope_dataset.as_json}, status: :ok
  end

  # POST /api/admin/scope_datasets
  def create
    @scope_dataset = ScopeDataset.create!(scope_dataset_params)
    render json: {success: true, message: "Scope Dataset Created Successfully", data: @scope_dataset.as_json}, status: :ok
  end

  # PATCH /api/admin/scope_datasets/:id
  def update
    @scope_dataset.update!(scope_dataset_update_params)
    render json: {success: true, message: "Scope Dataset Updated Successfully", data: @scope_dataset.as_json}, status: :ok
  end

  private

  def load_scope_dataset
    @scope_dataset = ScopeDataset.find(params[:id])
  end

  # Full permitted params for create (data required by model validation)
  def scope_dataset_params
    params.require(:scope_dataset).permit(
      :site_scope_id, :slug, :name, :description, :data_type,
      :group_key, :variant_label, :dimension, :display_order,
      dimension_config: {},
      schema_config: [{}],
      chart_config: [{}],
      data: [{}]
    )
  end

  # Config-only params for update — excludes :data to prevent accidental
  # overwrite of large data arrays.  Pass data[] explicitly to overwrite.
  def scope_dataset_update_params
    params.require(:scope_dataset).permit(
      :name, :description, :group_key, :variant_label, :dimension, :display_order,
      dimension_config: {},
      schema_config: [{}],
      chart_config: [{}]
    )
  end
end
