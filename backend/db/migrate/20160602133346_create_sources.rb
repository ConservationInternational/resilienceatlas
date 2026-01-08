class CreateSources < ActiveRecord::Migration[6.0]
  def change
    create_table :sources do |t|
      t.string :source_type
      t.string :reference
      t.string :reference_short
      t.string :url
      t.string :contact_name
      t.string :contact_email
      t.string :license
      t.datetime :last_updated
      t.string :version

      t.timestamps null: false
    end
  end
end
