class CreateFeedbackFields < ActiveRecord::Migration[7.0]
  def change
    create_table :feedback_fields do |t|
      t.belongs_to :feedback, foreign_key: {on_delete: :cascade}, null: false
      t.belongs_to :parent, foreign_key: {on_delete: :cascade, to_table: :feedback_fields}
      t.string :feedback_field_type, null: false
      t.string :question
      t.jsonb :answers

      t.timestamps
    end
  end
end
