class MakeStringColumnsTranslatable < ActiveRecord::Migration[7.0]
  def change
    reversible do |dir|
      dir.up do
        Category.create_translation_table!({name: :string, description: :text}, migrate_data: true, remove_source_columns: true)
        Indicator.create_translation_table!({name: :string}, migrate_data: true, remove_source_columns: true)
        MapMenuEntry.create_translation_table!({label: :string}, migrate_data: true, remove_source_columns: true)
        Model.create_translation_table!({name: :string, description: :text, source: :text}, migrate_data: true, remove_source_columns: true)
        SitePage.create_translation_table!({title: :string, body: :text}, migrate_data: true, remove_source_columns: true)
        SiteScope.create_translation_table!({name: :string, linkback_text: :text}, migrate_data: true, remove_source_columns: true)
        Source.create_translation_table!({reference: :string, reference_short: :string, license: :string}, migrate_data: true, remove_source_columns: true)
      end

      dir.down do
        revert_changes_for Category, name: :string, description: :text
        revert_changes_for Indicator, name: :string
        revert_changes_for MapMenuEntry, label: :string
        revert_changes_for Model, name: :string, description: :text, source: :text
        revert_changes_for SitePage, title: :string, body: :text
        revert_changes_for SiteScope, name: :string, linkback_text: :text
        revert_changes_for Source, reference: :string, reference_short: :string, license: :string
      end
    end
  end

  private

  def revert_changes_for(klass, attrs)
    attrs.each do |attr, column_type|
      add_column klass.table_name, attr, column_type
      migrate_translation_data klass, attr
    end
    klass.drop_translation_table!
  end

  def migrate_translation_data(klass, attribute)
    table_name = klass.table_name
    query = <<-SQL
      UPDATE #{table_name} 
      SET #{attribute} = #{table_name.singularize}_translations.#{attribute} 
      FROM #{table_name.singularize}_translations
      WHERE #{table_name}.id = #{table_name.singularize}_translations.#{table_name.singularize}_id
      AND #{table_name.singularize}_translations.locale = 'en'
    SQL
    execute query
  end
end
