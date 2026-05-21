class AddPublishedToJourney < ActiveRecord::Migration[7.0]
  def change
    add_column :journeys, :published, :boolean, null: false, default: false
  end
end
