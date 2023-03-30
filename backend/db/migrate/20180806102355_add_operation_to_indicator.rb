class AddOperationToIndicator < ActiveRecord::Migration[6.0]
  def change
    add_column :indicators, :operation, :string
  end
end
