class JourneysController < ApplicationController

  layout :resolve_layout

  def index
  end

  def show
  end

  private

  def resolve_layout
    case action_name
    when "index"
      "application"
    else
      "fullscreen"
    end
  end

end
