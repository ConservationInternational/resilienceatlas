class UpdateIndicatorAndModel < ActiveRecord::Migration[6.0]
  def change
    remove_column :indicators, :analysis_query
    remove_column :indicators, :analysis_suitable

    add_column :indicators, :category_id, :integer
    add_column :indicators, :position, :integer
    add_column :indicators, :column_name, :string

    add_foreign_key :indicators, :categories

    add_column :models, :query_analysis, :text
  end
end
