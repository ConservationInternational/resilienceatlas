class RegistrationsController < Devise::RegistrationsController
  respond_to :html, :json

  def create
    if request.env["CONTENT_TYPE"] == "application/json"
      build_resource(sign_up_params)
      resource.save

      if resource.errors.any?
        render json: resource.errors.to_json
      else
        render json: {status: "created"}, status: 200
      end
    else
      super
    end
  end
end
