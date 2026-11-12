ActiveAdmin.register Layer do
  menu label: "Layers", parent: "Map Content", priority: 1

  sidebar "About", only: :index do
    para "Layers are the core map data layers. Each layer defines a data source (COG raster, Martin vector tiles, or other provider), display style, legend, zoom range, and associated metadata."
  end

  includes :translations, :site_scopes

  permit_params do
    attributes = [:name, :slug, :published, :zindex, :order, :layer_config, :layer_provider, :opacity,
      :legend, :zoom_max, :zoom_min, :dashboard_order, :source_id, :data_units, :analysis_suitable, :analysis_type,
      :timeline, :timeline_steps, :timeline_start_date, :timeline_end_date, :timeline_default_date,
      :timeline_period, :analysis_query, :analysis_body, :interaction_config, :processing, :download,
      :description,
      source_ids: [],
      translations_attributes: [:id, :locale, :name, :legend, :data_units, :processing, :description, :analysis_text_template,
        :_destroy]]
    attributes << :data_policy if resource.new_record?
    attributes
  end

  controller do
    def current_ability
      @current_ability ||= Ability.new(current_admin_user)
    end

    rescue_from CanCan::AccessDenied do
      Rails.logger.warn "[Tile security admin] Access denied"
      head :forbidden
    end

    rescue_from ArgumentError do |error|
      Rails.logger.warn "[Tile security admin] #{error.message}"
      redirect_to(params[:id].present? ? admin_layer_path(params[:id]) : admin_layers_path, alert: error.message)
    end

    def save_resource(resource)
      ArcgisAdminCredentials.apply(resource, replacement: params[:arcgis_credential],
        clear: params[:clear_arcgis_credential] == "1")
      if resource.new_record? && !current_admin_user.superadmin?
        scope = SiteScope.find(params[:site_scope_id])
        raise CanCan::AccessDenied unless current_admin_user.allowed_site_scope_ids.include?(scope.id)

        resource.published = false if current_admin_user.contributor?
      else
        authorize! :update, resource
      end
      resource.timeline_steps = params["layer"]["timeline_steps"].to_s.split(",").map do |date|
        Date.strptime date.strip, "%Y-%m-%d"
      end
      Layer.transaction do
        saved = super
        Api::Admin::LayersManager.new(resource, scope.id).link_layer_group if saved && scope
        if saved
          TileSecurityEvent.create!(layer: resource, admin_user: current_admin_user,
            action: "save_layer", reason: "Layer saved in admin workspace",
            details: {version: resource.tile_cache_version, data_policy: resource.data_policy})
        end
        saved
      end
    rescue Date::Error
      resource.errors.add :timeline_steps, "Invalid date format"
      false
    end
  end

  member_action :duplicate, only: :show, method: :post do
    authorize! :update, resource
    authorize! :create, Layer
    n = resource.clone!
    Api::Admin::LayersManager.new(n, resource.site_scopes.first&.id).link_layer_group
    redirect_to edit_admin_layer_path(n)
  end

  # ── COG Upload ──────────────────────────────────────────────────────────────

  member_action :upload_cog, method: [:get, :post] do
    authorize! :update, resource
    redirect_to upload_admin_data_imports_path(layer_id: resource.id, import_type: "cog"),
      notice: request.post? ? "Use the upload workspace to validate and confirm this replacement." : nil
  end

  # ── Vector Import ────────────────────────────────────────────────────────────

  member_action :import_vector, method: [:get, :post] do
    authorize! :update, resource
    redirect_to upload_admin_data_imports_path(layer_id: resource.id, import_type: "vector"),
      notice: request.post? ? "Use the upload workspace to validate and confirm this replacement." : nil
  end

  filter :slug
  filter :translations_name_eq, as: :select, label: "Name", collection: proc { Layer.accessible_by(current_ability, :read).with_translations.pluck(:name).map(&:to_s).sort }
  filter :layer_provider, as: :select
  filter :analysis_suitable
  filter :timeline
  filter :layer_groups, as: :select, collection: proc { LayerGroup.accessible_by(current_ability, :read).with_translations.sort_by(&:name).map { |m| [m.name, m.id] } }
  filter :site_scopes, as: :select, collection: proc { SiteScope.accessible_by(current_ability, :read).with_translations.sort_by(&:name).map { |m| [m.name, m.id] } }

  member_action :publish, method: :put do
    TileSecurityManagement.new(current_admin_user).publish!(resource)
    redirect_to resource_path, notice: "Layer was published!"
  end

  member_action :unpublish, method: :put do
    authorize! :update, resource
    resource.with_lock do
      resource.update! published: false
      TileSecurityEvent.create!(layer: resource, admin_user: current_admin_user,
        action: "unpublish", reason: "Unpublished by administrator", details: {})
    end
    redirect_to resource_path, notice: "Layer was marked as not published!"
  end

  member_action :security_policy, method: :post do
    TileSecurityManagement.new(current_admin_user).set_policy!(resource,
      policy: params.require(:data_policy), reason: params.require(:reason))
    redirect_to resource_path, notice: "Data policy saved. Check pending CDN invalidations before considering revocation complete."
  end

  member_action :request_security_review, method: :post do
    TileSecurityManagement.new(current_admin_user).request_review!(resource, reason: params.require(:reason))
    redirect_to resource_path, notice: "Security review requested; access has not changed."
  end

  member_action :resolve_security_review, method: :post do
    review = TileSecurityReview.where(layer: resource).find(params[:review_id])
    TileSecurityManagement.new(current_admin_user).resolve_review!(review,
      approve: params[:decision] == "approve", reason: params.require(:reason))
    redirect_to resource_path, notice: "Review #{review.reload.status}."
  end

  member_action :refresh_preview, method: :post do
    authorize! :read, resource
    scope = resource.site_scopes.find_by(id: params[:site_scope_id]) || resource.site_scopes.first
    raise ActiveRecord::RecordNotFound unless scope
    response.cache_control.replace(private: true, no_store: true)
    render json: {preview_query: {site_scope: scope.subdomain, admin_preview_token: AdminPreviewAccess.issue(resource, current_admin_user)}.to_query}
  end

  member_action :verify_security, method: :post do
    verification = TileSecurityProbe.request!(resource, current_admin_user)
    redirect_to resource_path, notice: "Public-access verification #{verification.status}. Preview credentials are not used."
  end

  member_action :submit_tile_invalidation, method: :post do
    authorize! :update, resource
    raise CanCan::AccessDenied unless current_admin_user.superadmin?
    invalidation = TileCacheInvalidation.where(layer: resource).find(params[:invalidation_id])
    TileCacheInvalidationJob.perform_async(invalidation.id)
    redirect_to resource_path, notice: "Invalidation queued. Completion requires confirmation from CloudFront."
  end

  action_item :publish, only: :show, priority: 0, if: -> { !resource.published? && authorized?(:update, resource) } do
    link_to "Publish Layer", publish_admin_layer_path(resource), data: {method: :put}
  end

  action_item :unpublish, only: :show, priority: 0, if: -> { resource.published? && authorized?(:update, resource) } do
    link_to "Unpublish Layer", unpublish_admin_layer_path(resource), data: {method: :put}
  end

  action_item :upload_cog, only: :show, priority: 1, if: -> { authorized?(:update, resource) } do
    link_to "Upload COG", upload_cog_admin_layer_path(resource)
  end

  action_item :import_vector, only: :show, priority: 2, if: -> { authorized?(:update, resource) } do
    link_to "Import Vector", import_vector_admin_layer_path(resource)
  end

  index do
    selectable_column

    column :id
    column :name
    column :slug
    column :published
    column "Security" do |layer|
      policy = TileSecurityPolicy.new(layer).report
      status_tag policy.fetch("status")
      div policy.fetch("reasons").join(", ")
    end
    column :data_policy
    actions defaults: true do |layer|
      link_to "Duplicate", duplicate_admin_layer_path(layer), data: {method: :post} if authorized?(:update, layer)
    end
  end

  show do
    panel "Tile security and cache readiness" do
      render "admin/layers/security", layer: resource
    end
    attributes_table do
      row :id
      row :slug
      row :name
      row :description
      row :published
      row :processing
      row :data_units
      row :legend
      row :download
      row :layer_provider
      row :layer_config do |record|
        render "admin/shared/json_display", json: LayerSerializer.new(record).layer_config if record.layer_config.present?
      end
      row :opacity
      row :zindex
      row :order
      row :zoom_max
      row :zoom_min
      row :interaction_config do |record|
        render "admin/shared/json_display", json: record.interaction_config if record.interaction_config.present?
      end
      row :analysis_suitable
      if resource.analysis_suitable
        row :analysis_type
        row :analysis_query do |record|
          pre class: "code-block" do
            record.analysis_query
          end
        end
        row :analysis_body do |record|
          render "admin/shared/json_display", json: record.analysis_body if record.analysis_body.present?
        end
        row :analysis_text_template
      end
      row :timeline
      if resource.timeline
        row :timeline_steps do |record|
          record.timeline_steps.join(", ")
        end
        row :timeline_start_date
        row :timeline_end_date
        row :timeline_default_date
        row :timeline_period
      end
      row :dashboard_order
      row :sources do |record|
        if record.sources.any?
          ul do
            record.sources.each do |source|
              li link_to("#{source.source_type} - #{source.reference_short}", admin_source_path(source))
            end
          end
        end
      end
      row :created_at
      row :updated_at
    end

    imports = DataImport.where(importable: resource).order(created_at: :desc).limit(10)
    if imports.any?
      panel "Import History" do
        table_for imports do
          column :id
          column "Date", :created_at
          column "By" do |di|
            di.admin_user&.email
          end
          column :file_name
          column "Size", &:formatted_file_size
          column :import_type
          column :status do |di|
            status_tag di.status
          end
          column "Duration" do |di|
            di.duration ? "#{di.duration.round(1)}s" : "—"
          end
          column "" do |di|
            link_to "Details", admin_data_import_path(di)
          end
        end
      end
    end
  end

  form partial: "form"
end
