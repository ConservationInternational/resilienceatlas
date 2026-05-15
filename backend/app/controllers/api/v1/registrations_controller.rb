module Api
  module V1
    class RegistrationsController < ApiController
      def create
        user = User.new user_params
        if user.save
          render json: {status: "created"}, status: 200
        else
          # Format errors as { field: "message" } for frontend compatibility
          formatted_errors = user.errors.messages.transform_values { |messages| messages.first }
          render json: {errors: formatted_errors}, status: :unprocessable_entity
        end
      end

      private

      def user_params
        params.require(:user).permit(
          :first_name,
          :last_name,
          :email,
          :organization,
          :organization_role,
          :password,
          :password_confirmation
        )
      end
    end
  end
end
