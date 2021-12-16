
ActiveAdmin.register SiteScope do
  permit_params :name, :subdomain, :color, :analytics_code,
                :has_analysis, :latitude, :longitude,
                :header_theme, :zoom_level,  :linkback_text,
                :linkback_url, :header_color, :logo_url,
                :predictive_model, :analysis_options, :has_gef_logo

  member_action :clone, only: :show, method: :get do
    n = resource.clone!

    redirect_to edit_admin_site_scope_path( n )
  end              

  form do |f|
    f.inputs do
      f.semantic_errors
      f.input :name
      f.input :color
      f.input :header_theme, as: :select, collection: %w{ci-theme vs-theme}
      f.input :header_color, as: :color
      f.input :logo_url, as: :string
      f.input :analytics_code
      f.input :subdomain
      f.input :has_analysis
      f.input :linkback_text, as: :string
      f.input :linkback_url, as: :string
      f.input :predictive_model
      f.input :analysis_options
      f.input :has_gef_logo, label: 'Has GEF logo'
    end
    f.inputs :location, {data:{ geousable: 'yes'}} do
      f.input :latitude, :input_html => { :class => 'lat' }
      f.input :longitude, :input_html => { :class => 'lng' }
      f.input :zoom_level
    end
    
    actions defaults: true do |site_scope|
      link_to 'Clone', clone_admin_site_scope_path(site_scope)
    end

  end

  index do
    selectable_column

    column  :name
    column  :color
    column  :header_theme
    column  :header_color
    column  :logo_url
    column  :analytics_code
    column  :subdomain
    column  :has_analysis
    column  :linkback_text
    column  :linkback_url
    column  :predictive_model
    column  :analysis_options
    column  :has_gef_logo
    column  :latitude
    column  :longitude
    column  :zoom_level

    actions defaults: true do |site_scope|
      link_to 'Clone', clone_admin_site_scope_path(site_scope)
    end
  end

end
