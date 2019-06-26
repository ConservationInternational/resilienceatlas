require_relative '../../../commands/authorize_api_requests'

module Api
  module V1
    class ApiController < ApplicationController
      rescue_from ActiveRecord::RecordNotFound, :with => :record_not_found
      protect_from_forgery if: :json_request? # return null session when API call
      # before_action :authenticate_request, if: :json_request?
      before_action :set_locale
      skip_before_action :check_subdomain

      private
      def record_not_found
        render json: {errors: [{ status: '404', title: 'Record not found' }] } ,  status: 404
      end

      def authenticate_request
        @current_user = ::AuthorizeApiRequest.call(request.headers).result
        render json: { errors: [{ status: '401', title: 'Unauthorized' }] }, status: 401 unless @current_user
      end

      def set_locale
        I18n.locale = if params[:locale].present? && I18n.available_locales.map{|x| x.to_s}.include?(params[:locale])
                        params[:locale]
                      else
                        I18n.default_locale.to_s
                      end
      end
    end
  end
end
