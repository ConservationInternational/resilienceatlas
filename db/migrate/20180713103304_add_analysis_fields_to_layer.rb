class AddAnalysisFieldsToLayer < ActiveRecord::Migration
  def change
    add_column :layers, :analysis_suitable, :boolean, default: false
    add_column :layers, :analysis_query, :text
  end
end
