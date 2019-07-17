ActiveAdmin.register SiteScope do
  permit_params :name, :subdomain, :color, :analytics_code,
                :has_analysis, :latitude, :longitude,
                :header_theme, :zoom_level,  :linkback_text,
                :linkback_url, :header_color, :logo_url,
                :predictive_model, :analysis_options

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
    end
    f.inputs :location, {data:{ geousable: 'yes'}} do
      f.input :latitude, :input_html => { :class => 'lat' }
      f.input :longitude, :input_html => { :class => 'lng' }
      f.input :zoom_level
    end
    f.actions
  end
end
