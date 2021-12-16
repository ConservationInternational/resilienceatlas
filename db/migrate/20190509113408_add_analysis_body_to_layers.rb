class AddAnalysisBodyToLayers < ActiveRecord::Migration[6.0]
  def change
    add_column :layers, :analysis_body, :text
  end
end
