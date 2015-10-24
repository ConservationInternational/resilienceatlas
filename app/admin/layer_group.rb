ActiveAdmin.register LayerGroup do
  permit_params :name, :slug, :category, :active, :order, :info, :layer_group_type, :super_group_id, :icon_class, agrupations_attributes:[:layer_id, :id, :_destroy]
   form do |f|
    f.semantic_errors
    f.inputs "Layers" do
      f.has_many :agrupations, allow_destroy: true do |deg|
        deg.input :layer
      end
    end
    #f.inputs "Layers" do
    #  f.has_many :agrupations do |ag|
    #    if ag.object.present?
    #      f.input :_destroy, :as => :boolean, :label => "Remove?"
    #    end
    #    ag.input :layer, as: :select, collection: Layer.all.map{|l| [l.name, l.id]}
    #  end
    #end
    f.inputs 'Layer Group Details' do
    f.input :name
    f.input :slug
    f.input :category
    f.input :active
    f.input :active
    f.input :order
    f.input :info
    f.input :layer_group_type
    f.input :super_group_id
    f.input :icon_class
    f.actions
    end
  end
  index do
    selectable_column
    column :id
    column :name
    column :type
    column :order
    column :updated_at
    actions
  end
end
