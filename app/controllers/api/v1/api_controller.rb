module Api
  module V1
    class ApiController < ApplicationController
      rescue_from ActiveRecord::RecordNotFound, :with => :record_not_found
      before_action :verify_request
      before_action :set_locale
      skip_before_action :check_subdomain

      private
      def record_not_found
        render json: {errors: [{ status: '404', title: 'Record not found' }] } ,  status: 404
      end

      def verify_request
        Rails.logger.info form_authenticity_token
        unless verified_request?
          render json: {errors: [{ status: '401', title: 'Unauthorized' }] } ,  status: 401
        end
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
