class AddAnalysisBodyToLayers < ActiveRecord::Migration
  def change
    add_column :layers, :analysis_body, :text
  end
end
