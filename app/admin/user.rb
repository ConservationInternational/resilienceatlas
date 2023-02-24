# == Schema Information
#
# Table name: users
#
#  id                     :integer          not null, primary key
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  reset_password_token   :string
#  reset_password_sent_at :datetime
#  remember_created_at    :datetime
#  sign_in_count          :integer          default(0), not null
#  current_sign_in_at     :datetime
#  last_sign_in_at        :datetime
#  current_sign_in_ip     :inet
#  last_sign_in_ip        :inet
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  first_name             :string
#  last_name              :string
#  phone                  :string
#  organization           :string
#  organization_role      :string
#

ActiveAdmin.register User do
  permit_params :email, :password, :password_confirmation, :first_name, :last_name, :phone, :organization, :organization_role

  index do
    selectable_column
    id_column
    column :email
    column :first_name
    column :last_name
    column :phone
    column :organization
    column :organization_role
    column :current_sign_in_at
    column :sign_in_count
    column :created_at
    actions defaults: true do |user|
      link_to 'Show User Downloads', show_user_downloads_admin_user_path(user)
    end
  end

  filter :email
  filter :last_name
  filter :current_sign_in_at
  filter :sign_in_count
  filter :created_at

  member_action :show_user_downloads, method: :get do
    @user = User.find_by(id: params[:id])
    @user_downloads = UserDownload.where(user_id: @user.try(:id))
  end

  form do |f|
    f.inputs "User Details" do
      f.input :email
      f.input :password
      f.input :first_name
      f.input :last_name
      f.input :phone
      f.input :organization
      f.input :organization_role
    end
    f.actions
  end
end
