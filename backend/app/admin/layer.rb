ActiveAdmin.register Layer do
  includes :translations

  permit_params :name, :slug, :published, :zindex, :order, :query, :layer_config, :layer_provider, :css, :opacity,
    :legend, :zoom_max, :zoom_min, :dashboard_order, :source_id, :data_units, :analysis_suitable, :analysis_type,
    :timeline, :timeline_steps, :timeline_start_date, :timeline_end_date, :timeline_default_date,
    :timeline_period, :analysis_query, :analysis_body, :interaction_config, :processing, :download,
    :description,
    source_ids: [],
    translations_attributes: [:id, :locale, :name, :legend, :data_units, :processing, :description, :analysis_text_template,
      :_destroy]

  controller do
    def save_resource(resource)
      resource.timeline_steps = params["layer"]["timeline_steps"].to_s.split(",").map do |date|
        Date.strptime date.strip, "%Y-%m-%d"
      end
      super
    rescue Date::Error
      resource.errors.add :timeline_steps, "Invalid date format"
    end
  end

  member_action :duplicate, only: :show, method: :get do
    n = resource.clone!
    redirect_to edit_admin_layer_path(n)
  end

  filter :slug
  filter :translations_name_eq, as: :select, label: "Name", collection: proc { Layer.with_translations.pluck(:name).map(&:to_s).sort }
  filter :layer_provider, as: :select
  filter :analysis_suitable
  filter :timeline
  filter :layer_groups, as: :select, collection: proc { LayerGroup.with_translations.sort_by(&:name).map { |m| [m.name, m.id] } }
  filter :site_scopes, as: :select, collection: proc { SiteScope.with_translations.sort_by(&:name).map { |m| [m.name, m.id] } }

  member_action :publish, method: :put do
    resource.update! published: true
    redirect_to resource_path, notice: "Layer was published!"
  end

  member_action :unpublish, method: :put do
    resource.update! published: false
    redirect_to resource_path, notice: "Layer was marked as not published!"
  end

  action_item :publish, only: :show, priority: 0, if: -> { !resource.published? } do
    link_to "Publish Layer", publish_admin_layer_path(resource), data: {method: :put}
  end

  action_item :unpublish, only: :show, priority: 0, if: -> { resource.published? } do
    link_to "Unpublish Layer", unpublish_admin_layer_path(resource), data: {method: :put}
  end

  index do
    selectable_column

    column :id
    column :name
    column :slug
    column :published
    actions defaults: true do |layer|
      link_to "Duplicate", duplicate_admin_layer_path(layer)
    end
  end

  show do
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
      if resource.layer_provider == "cartodb"
        row :query do |record|
          pre class: "code-block" do
            record.query
          end
        end
        row :css do |record|
          pre class: "code-block" do
            record.css
          end
        end
        row :opacity
        row :zindex
        row :order
        row :zoom_max
        row :zoom_min
      else
        row :layer_config do |record|
          render "admin/shared/json_display", json: record.layer_config if record.layer_config.present?
        end
      end
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
  end

  form partial: "form"
end
