ActiveAdmin.register Category do
  permit_params :name, :slug, :description, indicator_ids: []

  filter :indicators, as: :select
  filter :name, as: :select
  filter :slug, as: :select
  filter :description

  index do
    selectable_column

    column :id
    column :name
    column :slug
    column :description
    column :indicators do |category|
      links = []
      category.indicators.map do |indicator|
        links << link_to(indicator.name, admin_indicator_path(indicator.id))
      end
      links.reduce(:+)
    end

    actions
  end

  form do |f|
    f.semantic_errors

    f.inputs 'Category fields' do
      f.input :name
      f.input :slug
      f.input :description
      f.input :indicators
    end

    f.actions
  end
end
