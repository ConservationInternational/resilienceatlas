ActiveAdmin.register Layer do
  permit_params :layer_group_id, :name, :slug, :layer_type, :zindex,
                :active, :order, :color, :info, :interactivity, :query, :layer_config,
                :layer_provider, :css, :published, :opacity, :locate_layer,
                :icon_class, :legend, :zoom_max, :zoom_min, :dashboard_order,
                :dataset_shortname, :dataset_source_url, :source_id, :title,
                :start_date, :end_date, :spatial_resolution, :spatial_resolution_units,
                :temporal_resolution, :temporal_resolution_units, :data_units,
                :analysis_suitable, :analysis_query, :analysis_body, :interaction_config,
                :update_frequency, :version, :processing, :download, :description, source_ids:[],
                translations_attributes: [:id, :locale, :name, :info, :legend, :title,
                                          :data_units, :processing, :description, :_destroy]

  member_action :clone, only: :show, method: :get do
    n = resource.clone!

    redirect_to edit_admin_layer_path( n )
  end

  filter :title, label: :name
  filter :layer_groups
  filter :slug
  filter :translations_name_contains, label: 'Name'
  filter :layer_type, as: :select
  filter :zindex, as: :select
  filter :active, as: :select
  filter :order
  filter :layer_provider, as: :select
  filter :css
  filter :interactivity

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

    f.inputs 'Translated fields' do
      f.translated_inputs switch_locale: false do |t|
        t.input :name
        t.input :info
        t.input :legend
        t.input :title
        t.input :data_units
        t.input :processing
        t.input :description
      end
    end

    f.inputs 'Layer Details' do

      f.input :slug
      f.input :layer_type, as: :select, collection: ['layer']
      f.input :opacity
      f.input :zindex
      f.input :active
      f.input :order
      f.input :dashboard_order
      #f.input :color, as: :string
      f.input :interactivity
      f.input :query
      f.input :layer_config
      f.input :interaction_config
      f.input :layer_provider, as: :select, collection: ['raster', 'cartodb', 'xyz tileset', 'gee']
      f.input :css
      f.input :locate_layer
      #f.input :icon_class
      f.input :zoom_max
      f.input :zoom_min
      f.input :download
      #f.input :dataset_shortname
      #f.input :dataset_source_url, as: :string
    end

    f.inputs "Common metadata sources" do
      f.input :sources, as: :select, collection: Source.all.map { |s| ["#{s.source_type} - Ref: #{s.reference_short}", s.id] }, label: 'Select sources:', multiple: true
    end

    f.inputs "Analysis" do
      f.input :analysis_suitable, input_html: { data: { if: 'checked', action: 'hide', target: '.query' }}
      f.input :analysis_query, wrapper_html: { class: 'query' }
      f.input :analysis_body
    end

    f.inputs "Metadata" do
      f.input :start_date, as: :date_picker
      f.input :end_date, as: :date_picker
      f.input :spatial_resolution
      f.input :spatial_resolution_units
      f.input :temporal_resolution
      f.input :temporal_resolution_units
      f.input :update_frequency
      f.input :version
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

  controller do
    def scoped_collection
      end_of_association_chain.includes([:translations])
    end
  end
end
