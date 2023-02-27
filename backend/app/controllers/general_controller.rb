class GeneralController < ApplicationController
  before_action :build_map_menu_entries

  private

  def build_map_menu_entries
    @map_menu_entries = MapMenuEntry.roots
  end
end
