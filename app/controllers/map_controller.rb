class MapController < GeneralController
  skip_before_action :check_subdomain

  layout 'fullscreen'

  def index
  end

end
