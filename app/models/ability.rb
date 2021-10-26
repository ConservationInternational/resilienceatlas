class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new # guest user (not logged in)
    case user.role
    when 'admin'
      # superusers can do everything, no need to specify
      can :manage, :all
    when 'manager'
      can :manage, :layers
    end

  end
end
