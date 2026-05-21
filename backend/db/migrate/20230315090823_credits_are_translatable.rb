class CreditsAreTranslatable < ActiveRecord::Migration[7.0]
  def change
    reversible do |dir|
      dir.up do
        Journey.add_translation_fields! credits: :string
        JourneyStep.add_translation_fields! credits: :string, source: :string
        migrate_translation_data Journey, :credits
        migrate_translation_data JourneyStep, :credits
        migrate_translation_data JourneyStep, :source
        remove_column :journeys, :credits
        remove_column :journey_steps, :credits
        remove_column :journey_steps, :source
      end

      dir.down do
        remove_column :journey_translations, :credits
        remove_column :journey_step_translations, :credits
        remove_column :journey_step_translations, :source
        add_column :journeys, :credits, :string
        add_column :journey_steps, :credits, :string
        add_column :journey_steps, :source, :string
      end
    end
  end

  private

  def migrate_translation_data(klass, attribute)
    table_name = klass.table_name
    query = <<-SQL
      UPDATE #{table_name.singularize}_translations 
      SET #{attribute} = #{table_name}.#{attribute} 
      FROM #{table_name} 
      WHERE #{table_name}.id = #{table_name.singularize}_translations.#{table_name.singularize}_id;
    SQL
    execute query
  end
end
