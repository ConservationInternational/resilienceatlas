ActiveAdmin.register Homepage do
  includes :translations, site_scope: :translations

  permit_params :site_scope_id, :credits_url, :background_image, :show_journeys,
    translations_attributes: [:id, :locale, :title, :subtitle, :credits, :_destroy],
    homepage_journey_attributes: [:id, :position, :_destroy, translations_attributes: [:id, :locale, :title, :_destroy]],
    homepage_sections_attributes: [:id, :button_url, :image, :image_position, :image_credits_url, :background_color, :position, :_destroy,
      translations_attributes: [:id, :locale, :title, :subtitle, :button_text, :image_credits, :_destroy]]

  config.filters = false

  controller do
    before_save do |resource|
      resource.homepage_journey = nil if params[:homepage][:show_journeys] == "0"
    end
  end

  index do
    id_column
    column :title
    column :subtitle
    column :site_scope
    column :show_journeys
    actions
  end

  show do
    attributes_table do
      row :id
      row :title
      row :subtitle
      row :site_scope
      row :background_image do |record|
        render "admin/shared/preview", blob: record.background_image if record.background_image.present?
      end
      row :credits
      row :credits_url
    end

    if homepage.show_journeys
      panel "Journeys" do
        attributes_table_for resource.homepage_journey do
          row :id
          row :title
          row :position
        end
      end
    end

    panel "Sections" do
      resource.homepage_sections.order(:position).each do |homepage_section|
        attributes_table_for homepage_section do
          row :id
          row :title
          row :subtitle
          row :button_text
          row :button_url
          row :image do |record|
            render "admin/shared/preview", blob: record.image if record.image.present?
          end
          row :image_position
          row :image_credits
          row :image_credits_url
          row :background_color do |record|
            render "admin/shared/color", color: record.background_color if record.background_color.present?
          end
          row :position
        end
      end
    end
  end

  form partial: "form"
end
