ActiveAdmin.register Journey do
  permit_params :credits, :credits_url, :background_image,
    translations_attributes: [:id, :locale, :title, :subtitle, :theme, :_destroy],
    journey_steps_attributes: [:id, :step_type, :position, :chapter_number, :credits, :credits_url,
      :map_theme, :map_url, :mask_sql, :btn_url, :background_image, :background_color, :_destroy,
      translations_attributes: [:id, :locale, :title, :subtitle, :theme, :content, :_destroy]]

  controller do
    def scoped_collection
      end_of_association_chain.includes :translations
    end

    def visible(journey_step, key)
      return unless JourneyStep::AVAILABLE_FIELDS_FOR_EVERY_TYPE[key][:available_at].include? journey_step.step_type.to_sym

      yield
    end
  end

  index do
    selectable_column

    column :id
    column :title
    column :created_at
    column :updated_at

    actions defaults: true
  end

  show do
    attributes_table do
      row :title
      row :subtitle
      row :theme
      row :background_image do |record|
        render "admin/shared/preview", blob: record.background_image if record.background_image.present?
      end
      row :created_at
      row :updated_at
    end

    panel "Journey Steps" do
      resource.journey_steps.order(:position).each do |journey_step|
        attributes_table_for journey_step do
          row :id
          row :step_type
          row :position
          controller.visible(journey_step, :title) { row :title }
          controller.visible(journey_step, :subtitle) { row :subtitle }
          controller.visible(journey_step, :theme) { row :theme }
          controller.visible(journey_step, :content) do
            row :content do |record|
              ActionText::Content.new(record.content)
            end
          end
          controller.visible(journey_step, :chapter_number) { row :chapter_number }
          controller.visible(journey_step, :credits) { row :credits }
          controller.visible(journey_step, :credits_url) { row :credits_url }
          controller.visible(journey_step, :map_theme) { row :map_theme }
          controller.visible(journey_step, :mask_sql) { row :mask_sql }
          controller.visible(journey_step, :map_url) { row :map_url }
          controller.visible(journey_step, :btn_url) { row :btn_url }
          controller.visible(journey_step, :background_color) do
            row :background_color do |record|
              render "admin/shared/color", color: record.background_color if record.background_color.present?
            end
          end
          controller.visible(journey_step, :background_image) do
            row :background_image do |record|
              render "admin/shared/preview", blob: record.background_image if record.background_image.present?
            end
          end
        end
      end
    end
  end

  form partial: "form"
end
