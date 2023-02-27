module Api
  module V1
    class JourneysController < ApiController
      def index
        journeys = File.read("public/journeys/journeysPageIndex.json")
        render json: journeys,
          meta: {total_categories: journeys.size}
      end

      def show
        id = %w[1 2 3 4 5].detect { |i| i == params[:id].to_s }
        journey_path = "public/journeys/#{id}.json"
        if File.exist? journey_path
          render json: File.read(journey_path)
        else
          render json: {errors: [{status: "404", title: "Record not found"}]}, status: 404
        end
      end
    end
  end
end
