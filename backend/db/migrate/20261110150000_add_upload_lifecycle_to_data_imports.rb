class AddUploadLifecycleToDataImports < ActiveRecord::Migration[7.2]
  def up
    change_column_null :data_imports, :importable_type, true
    change_column_null :data_imports, :importable_id, true
    add_column :data_imports, :options, :jsonb, null: false, default: {}
    add_column :data_imports, :metadata, :jsonb, null: false, default: {}
    add_column :data_imports, :previous_configuration, :jsonb, null: false, default: {}
    add_column :data_imports, :target_updated_at, :datetime
    add_column :data_imports, :upload_id, :text
    add_column :data_imports, :job_id, :string
    add_column :data_imports, :stage, :string
    add_column :data_imports, :attempts, :integer, null: false, default: 0
    execute "UPDATE data_imports SET importable_type = NULL, importable_id = NULL WHERE importable_type = 'AdminUser'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Standalone uploads no longer require a polymorphic target"
  end
end
