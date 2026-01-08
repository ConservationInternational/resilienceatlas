class AddDashboardOrderToLayers < ActiveRecord::Migration[6.0]
  def change
    add_column :layers, :dashboard_order, :integer
  end
end
