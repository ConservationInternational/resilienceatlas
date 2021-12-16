class AddTimestampsToModel < ActiveRecord::Migration[6.0]
  def change
    add_column :models, :created_at, :datetime, null: false, default: Time.now
    add_column :models, :updated_at, :datetime, null: false, default: Time.now
  end
end
