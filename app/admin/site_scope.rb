ActiveAdmin.register SiteScope do
  permit_params :name, :subdomain, :color, :has_analysis, :latitude, :longitude
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
      f.input :subdomain
      f.input :has_analysis
    end
    f.inputs :location, {data:{ geousable: 'yes'}} do
      f.input :latitude, :input_html => { :class => 'lat' }
      f.input :longitude, :input_html => { :class => 'lng' }
    end
    form partial: 'script'
    f.actions
  end
end
