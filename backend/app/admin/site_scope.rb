ActiveAdmin.register SiteScope do
  includes :translations

  permit_params :subdomain, :color, :has_analysis, :latitude, :longitude, :header_theme, :zoom_level,
    :linkback_url, :header_color, :logo_url, :predictive_model, :analysis_options, :has_gef_logo,
    translations_attributes: [:id, :locale, :name, :linkback_text, :_destroy]

  filter :layer_groups, as: :select, collection: proc { LayerGroup.with_translations.map { |m| [m.name, m.id] } }
  filter :site_pages, as: :select, collection: proc { SitePage.with_translations.map { |m| [m.title, m.id] } }
  filter :translations_name_eq, as: :select, label: "Name", collection: proc { SiteScope.with_translations.pluck(:name) }
  filter :subdomain
  filter :has_analysis
  filter :predictive_model
  filter :analysis_options
  filter :has_gef_logo
  filter :latitude
  filter :longitude

  member_action :clone, only: :show, method: :get do
    n = resource.clone!

    redirect_to edit_admin_site_scope_path(n)
  end

  form do |f|
    f.semantic_errors

    f.inputs "Translated fields" do
      f.translated_inputs switch_locale: false do |ff|
        ff.input :name
        ff.input :linkback_text
      end
    end

    f.inputs "Site scope fields" do
      f.input :color
      f.input :header_theme, as: :select, collection: %w[ci-theme vs-theme]
      f.input :header_color, as: :color
      f.input :logo_url, as: :string
      f.input :subdomain
      f.input :has_analysis
      f.input :linkback_url, as: :string
      f.input :predictive_model
      f.input :analysis_options
      f.input :has_gef_logo, label: "Has GEF logo"
    end

    f.inputs "Location", {data: {geousable: "yes"}} do
      f.input :latitude, input_html: {class: "lat"}
      f.input :longitude, input_html: {class: "lng"}
      f.input :zoom_level
    end

    f.actions
  end

  index do
    selectable_column

    column :name
    column :color
    column :header_theme
    column :header_color
    column :logo_url
    column :subdomain
    column :has_analysis
    column :linkback_text
    column :linkback_url
    column :predictive_model
    column :analysis_options
    column :has_gef_logo
    column :latitude
    column :longitude
    column :zoom_level

    actions defaults: true do |site_scope|
      link_to "Clone", clone_admin_site_scope_path(site_scope)
    end
  end

  show do
    attributes_table do
      row :id
      row :name
      row :color
      row :header_theme
      row :header_color
      row :logo_url
      row :subdomain
      row :has_analysis
      row :linkback_text
      row :linkback_url
      row :predictive_model
      row :analysis_options
      row :has_gef_logo
      row :latitude
      row :longitude
      row :zoom_level
    end
  end
end
