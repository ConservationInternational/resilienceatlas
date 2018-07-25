class AddTimestampsToIndicator < ActiveRecord::Migration
  def change
    add_column :indicators, :created_at, :datetime, null: false, default: Time.now
    add_column :indicators, :updated_at, :datetime, null: false, default: Time.now
  end
end
