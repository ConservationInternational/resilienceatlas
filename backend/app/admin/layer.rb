ActiveAdmin.register Layer do
  includes :translations

  permit_params :name, :slug, :published, :zindex, :order, :query, :layer_config, :layer_provider, :css, :opacity,
    :legend, :zoom_max, :zoom_min, :dashboard_order, :source_id, :data_units, :analysis_suitable,
    :analysis_query, :analysis_body, :interaction_config, :processing, :download, :description, source_ids: [],
    translations_attributes: [:id, :locale, :name, :legend, :data_units, :processing, :description, :_destroy]

  member_action :clone, only: :show, method: :get do
    n = resource.clone!
    redirect_to edit_admin_layer_path(n)
  end

  filter :slug
  filter :translations_name_eq, as: :select, label: "Name", collection: proc { Layer.with_translations.pluck(:name).sort }
  filter :layer_provider, as: :select
  filter :analysis_suitable
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
    link_to "Publish Layer", publish_admin_layer_path(resource), method: :put
  end

  action_item :unpublish, only: :show, priority: 0, if: -> { resource.published? } do
    link_to "Unpublish Layer", unpublish_admin_layer_path(resource), method: :put
  end

  index do
    selectable_column

    column :id
    column :name
    column :slug
    column :published
    actions defaults: true do |layer|
      link_to "Clone", clone_admin_layer_path(layer)
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
        row :query
        row :css
        row :opacity
        row :zindex
        row :order
        row :zoom_max
        row :zoom_min
      else
        row :layer_config
      end
      row :interaction_config
      row :analysis_suitable
      row :analysis_query if resource.analysis_suitable
      row :analysis_body if resource.analysis_suitable
      row :dashboard_order
    end
  end

  form partial: "form"
end
