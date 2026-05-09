module Api
  module V1
    class MenuEntriesController < ApiController
      def index
        menu_entries = MapMenuEntry.with_translations
        expires_in 1.hour, public: true, stale_while_revalidate: 5.minutes
        render json: menu_entries
      end
    end
  end
end
