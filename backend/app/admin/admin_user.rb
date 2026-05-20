ActiveAdmin.register AdminUser do
  menu label: "Admin Users", parent: "Users & Feedback", priority: 1

  sidebar "About", only: :index do
    para "Admin users have access to this administration panel."
    para "Superadmins can manage all site scopes. Other roles are restricted to their assigned site scopes."
    para "Contributors/Staff can only create layers (always unpublished) — they cannot update or delete."
  end

  permit_params :email, :password, :password_confirmation, :role,
    allowed_site_scope_ids: []

  index do
    selectable_column
    id_column
    column :email
    column :role
    column("Site Scopes") { |u| u.superadmin? ? "ALL" : u.allowed_site_scopes.map(&:name).join(", ").presence || "—" }
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
      f.input :role, as: :select, collection: AdminUser::ROLES.map { |r| [r.to_s.humanize, r] }
    end

    unless f.object.superadmin?
      f.inputs "Site Scope Access" do
        f.input :allowed_site_scope_ids,
          as: :check_boxes,
          collection: SiteScope.order(:name).map { |s| [s.name, s.id] },
          label: "Allowed Site Scopes",
          hint: "Superadmins have access to all site scopes and do not need explicit assignments."
      end
    end

    f.actions
  end

  show do
    attributes_table do
      row :email
      row :role
      row("Site Scope Access") do |u|
        if u.superadmin?
          status_tag "All site scopes", class: "yes"
        else
          scopes = u.allowed_site_scopes.map(&:name)
          scopes.any? ? scopes.join(", ") : status_tag("None assigned", class: "no")
        end
      end
      row :current_sign_in_at
      row :last_sign_in_at
      row :sign_in_count
      row :created_at
      row :updated_at
    end
  end

  controller do
    def update
      if params[:admin_user][:password].blank?
        params[:admin_user].delete(:password)
        params[:admin_user].delete(:password_confirmation)
      end
      # Overwrite site scope assignments
      resource.allowed_site_scope_ids = Array(params[:admin_user].delete(:allowed_site_scope_ids)).reject(&:blank?).map(&:to_i)
      super
    end
  end
end

