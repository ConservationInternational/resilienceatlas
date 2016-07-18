ActiveAdmin.register SiteScope do
  permit_params :name, :subdomain, :color, :has_analysis, :latitude, :longitude, :header_theme, :zoom_level,  :linkback_text, :linkback_url
# See permitted parameters documentation:
# https://github.com/activeadmin/activeadmin/blob/master/docs/2-resource-customization.md#setting-up-strong-parameters
#
# permit_params :list, :of, :attributes, :on, :model
#
# or
#
# permit_params do
#   permitted = [:permitted, :attributes]
#   permitted << :other if resource.something?
#   permitted
# end
  #form partial: 'form'

  form do |f|
    f.inputs do
      f.semantic_errors
      f.input :name
      f.input :color
      f.input :header_theme, as: :select, collection: %w{ci-theme vs-theme}
      f.input :subdomain
      f.input :has_analysis
      f.input :linkback_text, as: :string
      f.input :linkback_url, as: :string
    end
    f.inputs :location, {data:{ geousable: 'yes'}} do
      f.input :latitude, :input_html => { :class => 'lat' }
      f.input :longitude, :input_html => { :class => 'lng' }
      f.input :zoom_level
    end
    f.actions
  end
end
