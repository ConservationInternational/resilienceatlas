ActiveAdmin.register MapMenuEntry do
  sortable tree: true
  permit_params :label, :link, :ancestry, :position

  index as: :sortable do
    label :label
    actions
  end

  form do |f|
    f.semantic_errors

    f.inputs "Map Menu Entry fields" do
      f.input :label
      f.input :link
      f.input :position
    end

    f.actions
  end
end
