ActiveAdmin.register Feedback do
  menu label: "Feedbacks", parent: "Users & Feedback", priority: 4

  sidebar "About", only: :index do
    para "User-submitted feedback messages from the public-facing site. Review and manage visitor comments and contact requests."
  end

  actions :index, :show, :destroy

  config.filters = false

  controller do
    def show_detail_of(feedback_field, f)
      f.row feedback_field.question do
        Array.wrap(feedback_field.answer&.dig("value")).map(&:to_s).join(", ")
      end
    end
  end

  index do
    id_column
    column :language
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :language
      row :created_at

      panel "Answers" do
        resource.feedback_fields.where(parent_id: nil).order(:created_at).each do |feedback_field|
          attributes_table_for feedback_field do
            next controller.show_detail_of feedback_field, self if feedback_field.children.blank?

            panel feedback_field.question do
              feedback_field.children.each do |feedback_field_child|
                attributes_table_for feedback_field_child do
                  controller.show_detail_of feedback_field_child, self
                end
              end
            end
          end
        end
      end
    end
  end
end
