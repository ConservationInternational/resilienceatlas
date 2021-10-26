class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new # guest user (not logged in)
    case user.role
    when 'admin'
      # superusers can do everything, no need to specify
      can :manage, :all
    when 'manager'
      can :read, ActiveAdmin::Page, :name => "Dashboard"
      can :read, [Layer,User]
      can :manage, Layer
    when 'staff'
      can :read, ActiveAdmin::Page, :name => "Dashboard"
      can :read, Layer
    end
  end
end
