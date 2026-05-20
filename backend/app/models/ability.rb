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
    can :update, Layer, site_scope_id: allowed_ids
    can :read, [LayerGroup, Category]
  end
end
