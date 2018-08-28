class AddOperationToIndicator < ActiveRecord::Migration
  def change
    add_column :indicators, :operation, :string
  end
end
