class CreateIdentities < ActiveRecord::Migration[6.0]
  def change
    create_table :identities do |t|
      t.references :user, index: true, foreign_key: true
      t.string     :provider
      t.string     :uid

      t.timestamps null: false
    end
  end
end
