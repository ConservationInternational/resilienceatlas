ActiveAdmin.register SitePage do
  # See permitted parameters documentation:
  # https://github.com/activeadmin/activeadmin/blob/master/docs/2-resource-customization.md#setting-up-strong-parameters
  #
  permit_params :title, :body, :priority, :slug, :site_scope_id
  #  , :site_scope_id
  #
  # or
  #
  # permit_params do
  #   permitted = [:permitted, :attributes]
  #   permitted << :other if resource.something?
  #   permitted
  # end
  controller do
    helper ActionText::Engine.helpers
  end
  form do |f|
    f.inputs "Page details" do
      f.semantic_errors
      f.input :site_scope
      f.input :title
      f.inputs "Body" do
        f.rich_text_area :body
      end
      # f.cktext_area :body
      f.input :priority
      f.input :slug
      f.actions
    end
  end

  show do
    attributes_table :id, :site_scope, :title, :priority, :slug do
      row "Body" do |site_page|
        site_page.body.body
      end
    end
  end
end
