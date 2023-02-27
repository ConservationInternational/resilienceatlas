class ContentsController < GeneralController
  def show
    @page = SitePage.find_by(slug: params[:slug])
  end
end
