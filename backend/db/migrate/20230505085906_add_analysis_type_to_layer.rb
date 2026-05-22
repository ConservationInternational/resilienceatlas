class AddAnalysisTypeToLayer < ActiveRecord::Migration[7.0]
  def up
    add_column :layers, :analysis_type, :string, null: true
    Layer.add_translation_fields! analysis_text_template: :text
    add_default_value!
  end

  def down
    remove_column :layers, :analysis_type
    remove_column :layer_translations, :analysis_text_template
  end

  private

  def add_default_value!
    Layer.where(analysis_suitable: true).update_all analysis_type: "histogram"
  end
end
