ActiveAdmin.register Journey do
  includes :translations

  permit_params :credits_url, :background_image, :published,
    translations_attributes: [:id, :locale, :title, :subtitle, :theme, :credits, :_destroy],
    journey_steps_attributes: [:id, :step_type, :position, :chapter_number, :credits_url,
      :map_url, :mask_sql, :embedded_map_url, :background_image, :background_color, :_destroy,
      translations_attributes: [:id, :locale, :title, :subtitle, :description, :content, :credits, :source, :_destroy]]

  filter :created_at
  filter :updated_at
  filter :published

  controller do
    def visible(journey_step, key)
      return unless JourneyStep::AVAILABLE_FIELDS_FOR_EVERY_TYPE[key][:available_at].include? journey_step.step_type.to_sym

      yield
    end
  end

  member_action :publish, method: :put do
    resource.update! published: true
    redirect_to resource_path, notice: "Journey was published!"
  end

  member_action :unpublish, method: :put do
    resource.update! published: false
    redirect_to resource_path, notice: "Journey was marked as not published!"
  end

  action_item :publish, only: :show, priority: 0, if: -> { !resource.published? } do
    link_to "Publish Journey", publish_admin_journey_path(resource), data: { method: :put }
  end

  action_item :unpublish, only: :show, priority: 0, if: -> { resource.published? } do
    link_to "Unpublish Journey", unpublish_admin_journey_path(resource), data: { method: :put }
  end

  index do
    selectable_column

    column :id
    column :title
    column :subtitle
    column :published
    column :created_at
    column :updated_at

    actions defaults: true
  end

  show do
    attributes_table do
      row :id
      row :title
      row :subtitle
      row :theme
      row :published
      row :credits
      row :credits_url
      row :background_image do |record|
        render "admin/shared/preview", blob: record.background_image if record.background_image.present?
      end
      row :frontend_link do |record|
        link_to nil, "#{ENV["FRONTEND_URL"]}/journeys/#{record.id}"
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
          controller.visible(journey_step, :description) { row :description }
          controller.visible(journey_step, :content) do
            row :content do |record|
              ActionText::Content.new(record.content)
            end
          end
          controller.visible(journey_step, :chapter_number) { row :chapter_number }
          controller.visible(journey_step, :credits) { row :credits }
          controller.visible(journey_step, :credits_url) { row :credits_url }
          controller.visible(journey_step, :source) { row :source }
          controller.visible(journey_step, :mask_sql) { row :mask_sql }
          controller.visible(journey_step, :map_url) { row :map_url }
          controller.visible(journey_step, :embedded_map_url) { row :embedded_map_url }
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
