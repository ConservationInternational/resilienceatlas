ActiveAdmin.register StaticPage::Base do
  includes :translations

  permit_params :slug, :image, :image_credits_url,
    translations_attributes: [:id, :locale, :title, :image_credits, :_destroy],
    sections_attributes: [:id, :slug, :title_size, :show_at_navigation, :section_type, :position, :_destroy,
      translations_attributes: [:id, :locale, :title, :_destroy],
      section_paragraph_attributes: [:id, :image, :image_position, :image_credits_url, :position, :_destroy, translations_attributes: [:id, :locale, :text, :image_credits, :_destroy]],
      section_items_attributes: [:id, :image, :position, :_destroy, translations_attributes: [:id, :locale, :title, :description, :_destroy]],
      section_references_attributes: [:id, :slug, :position, :_destroy, translations_attributes: [:id, :locale, :text, :_destroy]]]

  config.filters = false

  controller do
    after_save do |resource|
      resource.sections.each do |section|
        section.section_paragraph.destroy unless section.section_type == "paragraph"
        section.section_items.destroy_all unless section.section_type == "items"
        section.section_references.destroy_all unless section.section_type == "references"
      end
    end
  end

  index do
    id_column
    column :slug
    column :title
    actions
  end

  show do
    attributes_table do
      row :id
      row :slug
      row :title
      row :image do |record|
        render "admin/shared/preview", blob: record.image if record.image.present?
      end
      row :image_credits
      row :image_credits_url
    end

    panel "Sections" do
      resource.sections.order(:position).each do |section|
        panel section.title do
          attributes_table_for section do
            row :id
            row :slug
            row :title
            row :title_size
            row :show_at_navigation
            if section.section_type == "paragraph"
              attributes_table_for section.section_paragraph do
                row :image do |record|
                  render "admin/shared/preview", blob: record.image if record.image.present?
                end
                row :image_position
                row :image_credits
                row :image_credits_url
                row :text do |record|
                  ActionText::Content.new(record.text)
                end
              end
            elsif section.section_type == "items"
              panel "Items" do
                section.section_items.order(:position).each do |item|
                  attributes_table_for item do
                    row :image do |record|
                      render "admin/shared/preview", blob: record.image if record.image.present?
                    end
                    row :title
                    row :description do |record|
                      ActionText::Content.new(record.description)
                    end
                  end
                end
              end
            elsif section.section_type == "references"
              panel "References" do
                section.section_references.order(:position).each do |reference|
                  attributes_table_for reference do
                    row :slug
                    row :text do |record|
                      ActionText::Content.new(record.text)
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  form partial: "form"
end
