ActiveAdmin.register AdminUser do
  permit_params :email, :password, :password_confirmation, :role

  index do
    selectable_column
    id_column
    column :email
    column :role
    column :current_sign_in_at
    column :sign_in_count
    column :created_at
    actions
  end

  filter :email
  filter :role, as: :select, collection: AdminUser.roles
  filter :current_sign_in_at
  filter :last_sign_in_at
  filter :sign_in_count
  filter :created_at
  filter :updated_at

  form do |f|
    f.inputs "Admin Details" do
      f.input :email
      if f.object.new_record?
        f.input :password
        f.input :password_confirmation
      end
      f.input :role
    end
    f.actions
  end

end
