class AddTileSecurityManagement < ActiveRecord::Migration[8.1]
  def change
    create_table :tile_security_events do |t|
      t.references :layer, index: true
      t.references :admin_user, index: true
      t.string :action, null: false
      t.text :reason, null: false
      t.jsonb :details, null: false, default: {}
      t.timestamps
    end
    create_table :tile_security_reviews do |t|
      t.references :layer, null: false, index: true
      t.references :admin_user, null: false, index: true
      t.string :status, null: false, default: "pending"
      t.string :source_version, null: false
      t.text :reason, null: false
      t.text :resolution
      t.timestamps
    end
    create_table :tile_cache_invalidations do |t|
      t.references :layer, index: true
      t.jsonb :paths, null: false, default: []
      t.string :status, null: false, default: "pending"
      t.string :external_id
      t.jsonb :requests, null: false, default: {}
      t.text :error_message
      t.timestamps
    end
    create_table :tile_security_verifications do |t|
      t.references :layer, null: false, index: true
      t.references :admin_user, null: false, index: true
      t.string :source_version, null: false
      t.string :status, null: false, default: "pending"
      t.jsonb :results, null: false, default: {}
      t.timestamps
    end
  end
end
