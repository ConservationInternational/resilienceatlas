class Ability
  include CanCan::Ability

  def initialize(admin_user)
    @admin_user = admin_user

    # superadmin and admin both get full access
    admin_rights if @admin_user.admin? || @admin_user.superadmin?
    # contributor? covers both :contributor and :staff roles (see AdminUser model)
    staff_rights if @admin_user.contributor?
  end

  private

  def admin_rights
    can :manage, :all
  end

  def staff_rights
    can :read, ActiveAdmin::Page, name: "Dashboard"
    allowed_ids = @admin_user.allowed_site_scopes.pluck(:id)
    can :read, Layer
    # Layer has many site_scopes via layer_groups (no direct site_scope_id column).
    can :update, Layer, site_scopes: {id: allowed_ids}
    can :read, [LayerGroup, Category]
  end
end
