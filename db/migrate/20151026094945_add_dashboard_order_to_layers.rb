class AddDashboardOrderToLayers < ActiveRecord::Migration
  def change
    add_column :layers, :dashboard_order, :integer
  end
end
