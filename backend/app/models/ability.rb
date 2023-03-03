class Ability
  include CanCan::Ability

  def initialize(admin_user)
    @admin_user = admin_user

    admin_rights if @admin_user.admin?
    manager_rights if @admin_user.manager?
    staff_rights if @admin_user.staff?
  end

  private

  def admin_rights
    can :manage, :all
  end

  def manager_rights
    can :read, ActiveAdmin::Page, name: "Dashboard"
    can :manage, [LayerGroup, Category, MapMenuEntry, Model, SitePage, SiteScope, Source, User]
    can [:create, :update, :read], [Layer]
  end

  def staff_rights
    can :read, ActiveAdmin::Page, name: "Dashboard"
    can :read, [Layer, LayerGroup, Category]
  end
end
