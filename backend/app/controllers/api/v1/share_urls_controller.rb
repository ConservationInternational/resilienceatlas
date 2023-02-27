module Api
  module V1
    class ShareUrlsController < ApiController
      def show
        @url = ShareUrl.find_by(uid: params[:uid])
        if @url.present?
          render json: @url
        else
          render json: {errors: [{status: "404", title: "Record not found"}]}, status: 404
        end
      end

      def create
        @url = ShareUrl.new(share_url_params)
        if @url.save
          render json: {uid: @url.uid}, status: 200
        else
          render json: {errors: [{status: "400", title: "Bad request"}]}, status: 400
        end
      end

      private

      def share_url_params
        params.permit(:body)
      end
    end
  end
end
