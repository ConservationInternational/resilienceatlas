ActiveAdmin.register Layer do
  permit_params :layer_group_id, :name, :slug, :layer_type, :zindex,
                :active, :order, :color, :info, :interactivity, :query,
                :layer_provider, :css, :published, :opacity, :locate_layer,
                :icon_class, :legend, :zoom_max, :zoom_min, :dashboard_order,
                :dataset_shortname, :dataset_source_url, :source_id, :title,
                :start_date, :end_date, :spatial_resolution, :spatial_resolution_units,
                :temporal_resolution, :temporal_resolution_units, :data_units,
                :update_frequency, :version, :processing, :download, :description

  member_action :clone, only: :show, method: :get do
    n = resource.clone!

    redirect_to edit_admin_layer_path( n )
  end

  index do
    selectable_column

    column :id
    column :name
    column :slug
    column :active
    column :published
    actions defaults: true do |layer|
      link_to 'Clone', clone_admin_layer_path(layer)
    end
  end

  form do |f|
    f.semantic_errors
    f.inputs 'Layer Details' do
      f.input :name
      f.input :slug
      f.input :layer_type, as: :select, collection: ['layer']
      f.input :opacity
      f.input :zindex
      f.input :active
      f.input :order
      f.input :dashboard_order
      #f.input :color, as: :string
      f.input :info
      f.input :interactivity
      f.input :query
      f.input :layer_provider, as: :select, collection: ['raster', 'cartodb']
      f.input :css
      f.input :locate_layer
      #f.input :icon_class
      f.input :legend
      f.input :zoom_max
      f.input :zoom_min
      f.input :download
      #f.input :dataset_shortname
      #f.input :dataset_source_url, as: :string
    end

    f.inputs "Common metadata source" do
      f.input :source, as: :select, collection: Source.all.map { |s| ["#{s.source_type} - Ref: #{s.reference_short}", s.id] }, label: 'Select a source:'
    end

    f.inputs "Metadata" do
      f.input :title
      f.input :description
      f.input :start_date, as: :date_picker
      f.input :end_date, as: :date_picker
      f.input :spatial_resolution
      f.input :spatial_resolution_units
      f.input :temporal_resolution
      f.input :temporal_resolution_units
      f.input :data_units
      f.input :update_frequency
      f.input :version
      f.input :processing
    end
    f.actions
  end

  index do
    selectable_column
    column :id
    column :name
    column :provider
    column :download
    column :css
    column :query
    column :info
    column :updated_at
    column :source
    actions
  end
end
