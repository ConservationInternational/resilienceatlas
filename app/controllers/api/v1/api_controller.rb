module Api
  module V1
    class ApiController < ApplicationController
      rescue_from ActiveRecord::RecordNotFound, :with => :record_not_found
      before_action :verify_request
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
    end
  end
end
