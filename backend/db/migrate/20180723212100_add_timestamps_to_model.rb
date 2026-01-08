class AddTimestampsToModel < ActiveRecord::Migration[6.0]
  def change
    # Note: Using -> { "CURRENT_TIMESTAMP" } for a stable default that doesn't
    # change schema.rb on every migration run (unlike Time.now which is evaluated once)
    add_column :models, :created_at, :datetime, null: false, default: -> { "CURRENT_TIMESTAMP" }
    add_column :models, :updated_at, :datetime, null: false, default: -> { "CURRENT_TIMESTAMP" }
  end
end
