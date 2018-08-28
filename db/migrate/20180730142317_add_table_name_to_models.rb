class AddTableNameToModels < ActiveRecord::Migration
  def change
    add_column :models, :table_name, :string
  end
end
