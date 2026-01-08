class AddTableNameToModels < ActiveRecord::Migration[6.0]
  def change
    add_column :models, :table_name, :string
  end
end
