class AddAnalysisBodyToLayers < ActiveRecord::Migration
  def change
    add_column :layers, :analysis_body, :string
  end
end
