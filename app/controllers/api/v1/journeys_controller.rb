module Api
  module V1
    class JourneysController < ApiController

      def index
        journeys = File.read('public/journeys/journeysPageIndex.json')
        render json: journeys,
               meta: { total_categories: journeys.size }
      end

      def show
        journey = File.read("public/journeys/#{params[:id]}.json")
        if journey
          render json: journey
        else
          render json: {errors: [{ status: '404', title: 'Record not found' }] } ,  status: 404
        end
      end

    end
  end
end
