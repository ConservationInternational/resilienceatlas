class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def facebook
    provider('facebook')
  end

  def twitter
    provider('twitter')
  end

  def linkedin
    provider('linked_in')
  end

  def google_oauth2
    provider('google_oauth2')
  end

  def failure
    redirect_to root_path
  end

  private

    def provider(provider)
      @user = User.for_oauth(env['omniauth.auth'], current_user)

      if @user.persisted?
        sign_in_and_redirect @user, event: :authentication
        set_flash_message(:notice, :success, kind: "#{provider}".capitalize) if is_navigational_format?
      else
        session["devise.#{provider}_data"] = env['omniauth.auth']
        redirect_to new_user_registration_url
      end
    end

    def after_sign_in_path_for(resource)
      if resource.email_verified?
        super resource
      else
        finish_signup_path(resource)
      end
    end
end

