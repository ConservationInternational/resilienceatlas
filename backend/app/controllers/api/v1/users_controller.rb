module Api
  module V1
    class UsersController < ApiController
      before_action :authenticate_request

      def edit
        render json: current_user
      end

      def update
        if current_user.update(user_params)
          render json: current_user
        else
          render json: {errors: current_user.errors}, status: :unprocessable_entity
        end
      end

      private

      def user_params
        accessible = [:first_name, :last_name, :email, :organization, :organization_role]
        accessible << [:password, :password_confirmation] unless params[:user][:password].blank?
        params.require(:user).permit(accessible)
      end
    end
  end
end
