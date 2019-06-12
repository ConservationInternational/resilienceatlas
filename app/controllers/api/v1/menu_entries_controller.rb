module Api
  module V1
    class MenuEntriesController < ApiController
      def index
        menu_entries = MapMenuEntry.all
        render json: menu_entries
      end
    end
  end
end
