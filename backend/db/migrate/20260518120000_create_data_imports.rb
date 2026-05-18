class CreateDataImports < ActiveRecord::Migration[7.2]
  def change
    create_table :data_imports do |t|
      t.string  :importable_type, null: false
      t.bigint  :importable_id,   null: false
      t.bigint  :admin_user_id,   null: false
      t.string  :file_name
      t.string  :s3_key
      t.bigint  :file_size_bytes
      t.string  :import_type,    null: false
      t.string  :status,         null: false, default: "pending"
      t.text    :error_message
      t.integer :rows_imported
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end

    add_index :data_imports, [:importable_type, :importable_id]
    add_index :data_imports, :admin_user_id
    add_index :data_imports, :status
    add_foreign_key :data_imports, :admin_users
  end
end
