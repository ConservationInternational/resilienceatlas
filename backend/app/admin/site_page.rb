ActiveAdmin.register SitePage do
  includes :translations, site_scope: :translations
  permit_params :priority, :slug, :site_scope_id,
    translations_attributes: [:id, :locale, :title, :body, :_destroy]

  filter :site_scope, as: :select, collection: proc { SiteScope.with_translations.map { |m| [m.name, m.id] } }
  filter :translations_title_cont, as: :string, label: "Title"
  filter :slug
  filter :priority

  index do
    selectable_column

    column :id
    column :title
    column :slug
    column :priority
    column :site_scope
    actions
  end

  show do
    attributes_table :id, :site_scope, :title, :priority, :slug do
      row "Body" do |site_page|
        ActionText::Content.new(site_page.body)
      end
    end
  end

  form partial: "form"
end
