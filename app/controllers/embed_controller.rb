class EmbedController < ApplicationController

  after_action :allow_iframe
  layout 'embed'

  def show
  end

  private

    def allow_iframe
      response.headers.except! 'X-Frame-Options'
    end

end
