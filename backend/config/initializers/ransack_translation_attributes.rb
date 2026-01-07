# Configure ransackable attributes for Globalize translation models
# This is required by Ransack 4.x which requires explicit allowlisting of searchable attributes

Rails.application.config.after_initialize do
  # Helper method to safely configure translation class
  def configure_translation_ransack(model_name, table_name, attributes, association_name)
    return unless ActiveRecord::Base.connection.table_exists?(table_name)

    model = model_name.safe_constantize
    return unless model&.respond_to?(:translation_class) && model.translation_class

    model.translation_class.class_eval do
      define_singleton_method(:ransackable_attributes) { |_auth_object = nil| attributes }
      define_singleton_method(:ransackable_associations) { |_auth_object = nil| [association_name] }
    end
  end

  # Category translations
  configure_translation_ransack(
    "Category",
    "category_translations",
    %w[created_at id id_value locale category_id updated_at name description],
    "category"
  )

  # Homepage translations
  configure_translation_ransack(
    "Homepage",
    "homepage_translations",
    %w[created_at id id_value locale homepage_id updated_at title subtitle credits],
    "homepage"
  )

  # HomepageJourney translations
  configure_translation_ransack(
    "HomepageJourney",
    "homepage_journey_translations",
    %w[created_at id id_value locale homepage_journey_id updated_at title subtitle],
    "homepage_journey"
  )

  # HomepageSection translations
  configure_translation_ransack(
    "HomepageSection",
    "homepage_section_translations",
    %w[created_at id id_value locale homepage_section_id updated_at title subtitle button_text image_credits],
    "homepage_section"
  )

  # Indicator translations
  configure_translation_ransack(
    "Indicator",
    "indicator_translations",
    %w[created_at id id_value locale indicator_id updated_at name],
    "indicator"
  )

  # Journey translations
  configure_translation_ransack(
    "Journey",
    "journey_translations",
    %w[created_at id id_value locale journey_id updated_at title subtitle theme credits],
    "journey"
  )

  # JourneyStep translations
  configure_translation_ransack(
    "JourneyStep",
    "journey_step_translations",
    %w[created_at id id_value locale journey_step_id updated_at title subtitle description content credits source],
    "journey_step"
  )

  # Layer translations
  configure_translation_ransack(
    "Layer",
    "layer_translations",
    %w[created_at id id_value locale layer_id updated_at name info legend title data_units processing description analysis_text_template],
    "layer"
  )

  # LayerGroup translations
  configure_translation_ransack(
    "LayerGroup",
    "layer_group_translations",
    %w[created_at id id_value locale layer_group_id updated_at name info],
    "layer_group"
  )

  # MapMenuEntry translations
  configure_translation_ransack(
    "MapMenuEntry",
    "map_menu_entry_translations",
    %w[created_at id id_value locale map_menu_entry_id updated_at label],
    "map_menu_entry"
  )

  # Model translations
  configure_translation_ransack(
    "Model",
    "model_translations",
    %w[created_at id id_value locale model_id updated_at name description source],
    "model"
  )

  # SitePage translations
  configure_translation_ransack(
    "SitePage",
    "site_page_translations",
    %w[created_at id id_value locale site_page_id updated_at title body],
    "site_page"
  )

  # SiteScope translations
  configure_translation_ransack(
    "SiteScope",
    "site_scope_translations",
    %w[created_at id id_value locale site_scope_id updated_at name linkback_text],
    "site_scope"
  )

  # Source translations
  configure_translation_ransack(
    "Source",
    "source_translations",
    %w[created_at id id_value locale source_id updated_at reference reference_short license],
    "source"
  )

  # StaticPage::Base translations
  configure_translation_ransack(
    "StaticPage::Base",
    "static_page_base_translations",
    %w[created_at id id_value locale static_page_base_id updated_at title image_credits],
    "static_page_base"
  )

  # StaticPage::Section translations
  configure_translation_ransack(
    "StaticPage::Section",
    "static_page_section_translations",
    %w[created_at id id_value locale static_page_section_id updated_at title],
    "static_page_section"
  )

  # StaticPage::SectionItem translations
  configure_translation_ransack(
    "StaticPage::SectionItem",
    "static_page_section_item_translations",
    %w[created_at id id_value locale static_page_section_item_id updated_at title description],
    "static_page_section_item"
  )

  # StaticPage::SectionParagraph translations
  configure_translation_ransack(
    "StaticPage::SectionParagraph",
    "static_page_section_paragraph_translations",
    %w[created_at id id_value locale static_page_section_paragraph_id updated_at text image_credits],
    "static_page_section_paragraph"
  )

  # StaticPage::SectionReference translations
  configure_translation_ransack(
    "StaticPage::SectionReference",
    "static_page_section_reference_translations",
    %w[created_at id id_value locale static_page_section_reference_id updated_at text],
    "static_page_section_reference"
  )
rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished, ActiveRecord::StatementInvalid => e
  Rails.logger&.info "Skipping ransack translation attributes setup - database not ready: #{e.message}"
end
