class CreateStaticPageBases < ActiveRecord::Migration[7.0]
  def change
    create_table :static_page_bases do |t|
      t.string :slug, null: false, index: {unique: true}
      t.string :image_credits_url

      t.timestamps
    end

    reversible do |dir|
      dir.up do
        StaticPage::Base.create_translation_table! title: :string, image_credits: :string
      end

      dir.down do
        StaticPage::Base.drop_translation_table!
      end
    end
  end
end
