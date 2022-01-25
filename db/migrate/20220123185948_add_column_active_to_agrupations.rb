class AddColumnActiveToAgrupations < ActiveRecord::Migration[6.1]
  def change
  	add_column :agrupations, :active, :boolean, default: false
  end
end
