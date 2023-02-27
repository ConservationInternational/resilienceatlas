ActiveAdmin.register LayerGroup do
  permit_params :name, :slug, :category, :active, :order, :info, :layer_group_type, :super_group_id, :icon_class,
    :site_scope_id, agrupations_attributes: [:layer_id, :id, :active, :_destroy],
    translations_attributes: [:id, :locale, :name, :info, :_destroy]

  member_action :clone, only: :show, method: :get do
    n = resource.clone!

    redirect_to edit_admin_layer_group_path(n)
  end

  form do |f|
    f.semantic_errors

    f.inputs "Translated fields" do
      f.translated_inputs switch_locale: false do |t|
        t.input :name
        t.input :info
      end
    end

    f.inputs "Layers" do
      f.has_many :agrupations, allow_destroy: true do |deg|
        deg.input :layer,
          as: :select,
          collection: Layer.order("layer_translations.name")
            .map { |l| ["#{l.name} - id: #{l.id}", l.id] }
        deg.input :active
      end
      f.input :site_scope
    end
    f.inputs "Layer Group Details" do
      f.input :slug
      # f.input :category
      f.input :active
      f.input :order
      f.input :layer_group_type, as: :select, collection: %w[group category subcategory subgroup]
      f.input :super_group,
        as: :select,
        collection: LayerGroup.with_translations
          .order("layer_group_translations.name").map { |lg| ["#{lg.name} - #{lg.id}", lg.id] }
      # f.input :icon_class
      f.actions
    end
  end
  index do
    selectable_column
    column :id
    column :name
    column :layer_group_type
    column :site_scope do |lg|
      SiteScope.find(lg.site_scope_id).name if lg.site_scope_id.present?
    end
    column :layers do |lg|
      lg.layers.map { |l| l.name }.join(", ")
    end
    column :order
    column :updated_at
    actions defaults: true do |layer_group|
      link_to "Clone", clone_admin_layer_group_path(layer_group)
    end
  end
end
