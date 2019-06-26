class AddPredictiveModelAndAnalysisOptionsToSiteScope < ActiveRecord::Migration
  def change
    add_column :site_scopes, :predictive_model, :boolean, null: false, default: false
    add_column :site_scopes, :analysis_options, :boolean, null: false, default: false
  end
end
