ActiveAdmin.register SitePage do
  menu label: "Site Pages", parent: "Sites", priority: 2

  sidebar "About", only: :index do
    para "Site pages are custom informational pages attached to a specific site scope — for example, an About page or Methodology section for a particular scope."
  end

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
        translation = site_page.translations.find { |record| record.locale.to_s == I18n.locale.to_s } || site_page.translations.first
        ActionText::Content.new(translation&.body.to_s).to_plain_text if translation&.body.present?
      end
    end
  end

  form partial: "form"
end
