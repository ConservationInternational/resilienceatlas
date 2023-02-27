ActiveAdmin.register UserDownload do
  actions :index, :show

  permit_params :subdomain, :user_id, :layer_id

  index do
    id_column
    column :subdomain
    column :user do |obj|
      User.find_by(id: obj.user_id).try(:name) if obj.user_id.present?
    end
    column :layer do |obj|
      Layer.find_by(id: obj.layer_id).try(:name) if obj.layer_id.present?
    end
    actions
  end
end
