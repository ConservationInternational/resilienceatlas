# frozen_string_literal: true

# Custom replacement for activeadmin-globalize gem
# Provides translated_inputs form helper and active_admin_translates model extension
# that work directly with the Globalize gem without requiring the deprecated activeadmin-globalize

module ActiveAdmin
  module GlobalizeTranslations
    # Model extension - replaces activeadmin-globalize's active_admin_translates
    module ActiveRecordExtension
      def active_admin_translates(*args, &block)
        # Call Globalize's translates method
        translates(*args.dup)
        args.extract_options!

        # Execute block on translation class if provided (for validations)
        if block
          translation_class.instance_eval(&block)
        end

        # Enable nested attributes for translations (required for ActiveAdmin forms)
        accepts_nested_attributes_for :translations, allow_destroy: true

        # Include helper methods
        include TranslationMethods
      end

      module TranslationMethods
        def translation_names
          translations.map(&:locale).map do |locale|
            I18n.t("active_admin.globalize.language.#{locale}", default: locale.to_s.upcase)
          end.uniq.sort
        end
      end
    end

    # Form builder extension - replaces activeadmin-globalize's translated_inputs
    module FormBuilderExtension
      extend ActiveSupport::Concern

      # Renders translation inputs for each available locale
      # @param name [String] ignored, kept for compatibility
      # @param options [Hash] options hash
      # @option options [Array] :available_locales locales to show (default: I18n.available_locales)
      # @option options [Boolean] :switch_locale whether to switch I18n.locale when rendering (default: false)
      # @option options [Symbol] :default_locale the default locale tab to show (default: I18n.default_locale)
      def translated_inputs(name = "Translations", options = {}, &block)
        options = options.symbolize_keys
        available_locales = options.fetch(:available_locales, I18n.available_locales)
        switch_locale = options.fetch(:switch_locale, false)
        default_locale = options.fetch(:default_locale, I18n.default_locale)

        template.content_tag(:div, class: "activeadmin-translations") do
          # Inline JavaScript for tab switching (guaranteed to work without external JS)
          inline_js = template.content_tag(:script) do
            <<-JS.html_safe
              function switchTranslationTab(container, targetLocale) {
                // Update active tab
                var tabs = container.querySelectorAll('ul.locale-selector a');
                tabs.forEach(function(t) {
                  t.classList.remove('active');
                  t.parentElement.classList.remove('active');
                });
                event.target.classList.add('active');
                event.target.parentElement.classList.add('active');
                
                // Show/hide fieldsets
                var fieldsets = container.querySelectorAll('fieldset.locale');
                fieldsets.forEach(function(fs) {
                  if (fs.classList.contains('locale-' + targetLocale)) {
                    fs.classList.add('active');
                    fs.style.display = 'block';
                  } else {
                    fs.classList.remove('active');
                    fs.style.display = 'none';
                  }
                });
              }
            JS
          end

          # Render locale tabs with inline onclick handlers
          locale_tabs = template.content_tag(:ul, class: "available-locales locale-selector") do
            available_locales.map do |locale|
              is_default = (locale.to_sym == default_locale.to_sym)
              li_class = is_default ? "translation-tab active" : "translation-tab"
              a_class = is_default ? "default active" : nil
              template.content_tag(:li, class: li_class) do
                I18n.with_locale(switch_locale ? locale : I18n.locale) do
                  template.content_tag(:a, locale_label(locale),
                    href: "#",
                    class: a_class,
                    onclick: "switchTranslationTab(this.closest('.activeadmin-translations'), '#{locale}'); return false;")
                end
              end
            end.join.html_safe
          end

          # Render translation fieldsets
          translation_fields = available_locales.each_with_index.map do |locale, index|
            translation = object.translations.find { |t| t.locale.to_s == locale.to_s }
            translation ||= object.translations.build(locale: locale)

            fields = proc do |form|
              form.input(:locale, as: :hidden)
              form.input(:id, as: :hidden)
              I18n.with_locale(switch_locale ? locale : I18n.locale) do
                block.call(form)
              end
            end

            # Add 'active' class to default locale fieldset for CSS visibility
            is_default = (locale.to_sym == default_locale.to_sym)
            css_classes = "inputs locale locale-#{locale}"
            css_classes += " active" if is_default

            inputs_for_nested_attributes(
              for: [:translations, translation],
              class: css_classes,
              &fields
            )
          end.join.html_safe

          inline_js + locale_tabs + translation_fields
        end
      end

      private

      def locale_label(locale)
        I18n.t("active_admin.globalize.language.#{locale}", default: locale.to_s.upcase)
      end
    end

    # View helper for showing translated rows in show pages
    module AttributesTableExtension
      # Display a row with translations in show pages
      # @param field [Symbol] the translated field name
      # @param options [Hash] options hash
      # @option options [Boolean] :inline whether to show translations inline (default: true)
      # @option options [Symbol] :locale the initial locale to display (default: I18n.locale)
      def translated_row(*args, &block)
        options = args.extract_options!
        options = options.symbolize_keys.reverse_merge(inline: true, locale: I18n.locale)
        field = options[:field] || args.first

        row_options = options.except(:field, :locale, :inline)
        args.push(row_options) unless row_options.empty?

        row(*args) do
          if options[:inline]
            inline_translations(field, options[:locale], &block)
          else
            block_translations(field, options[:locale], &block)
          end
        end
      end

      private

      def inline_translations(field, initial_locale, &block)
        "".html_safe.tap do |value|
          value << inline_locale_selectors(field, initial_locale, &block)
          value << translation_spans(field, initial_locale, &block)
        end
      end

      def block_translations(field, initial_locale, &block)
        template.content_tag(:div, class: "activeadmin-translations") do
          "".html_safe.tap do |value|
            value << block_locale_selectors(field, initial_locale)
            value << translation_divs(field, initial_locale, &block)
          end
        end
      end

      def inline_locale_selectors(field, initial_locale, &block)
        template.content_tag(:span, class: "inline-locale-selector") do
          available_translations.map do |translation|
            content = translation_value(translation, field, &block)
            css_classes = ["ui-translation-trigger"]
            css_classes << "active" if translation.locale.to_sym == initial_locale.to_sym
            css_classes << "empty" if content.blank?
            template.link_to(flag_icon(translation.locale), "#", class: css_classes, data: {locale: translation.locale})
          end.join(" ").html_safe
        end
      end

      def block_locale_selectors(field, initial_locale)
        template.content_tag(:ul, class: "available-locales locale-selector") do
          available_translations.map do |translation|
            css_classes = ["translation-tab"]
            css_classes << "active" if translation.locale.to_sym == initial_locale.to_sym
            template.content_tag(:li, class: css_classes) do
              default_class = (translation.locale.to_sym == initial_locale.to_sym) ? "default" : nil
              template.content_tag(:a, locale_label(translation.locale), href: ".locale-#{translation.locale}", class: default_class)
            end
          end.join.html_safe
        end
      end

      def translation_spans(field, initial_locale, &block)
        available_translations.map do |translation|
          css_classes = ["field-translation", "locale-#{translation.locale}"]
          css_classes << "hidden" unless translation.locale.to_sym == initial_locale.to_sym
          content = translation_value(translation, field, &block)
          css_classes << "empty" if content.blank?
          template.content_tag(:span, content.presence || "Empty", class: css_classes)
        end.join(" ").html_safe
      end

      def translation_divs(field, initial_locale, &block)
        available_translations.map do |translation|
          css_classes = ["field-translation", "locale-#{translation.locale}"]
          css_classes << "hidden" unless translation.locale.to_sym == initial_locale.to_sym
          content = translation_value(translation, field, &block)
          template.content_tag(:div, class: css_classes) do
            content.presence || template.content_tag(:span, "Empty", class: "empty")
          end
        end.join.html_safe
      end

      def available_translations
        current_resource = respond_to?(:resource) ? resource : @record
        @available_translations ||= current_resource&.translations&.order(:locale) || []
      end

      def translation_value(translation, field)
        I18n.with_locale(translation.locale) do
          block_given? ? yield(translation) : translation.send(field)
        end
      end

      def flag_icon(locale)
        template.content_tag(:i, "", class: "flag flag-#{locale}", title: locale_label(locale))
      end

      def locale_label(locale)
        I18n.t("active_admin.globalize.language.#{locale}", default: locale.to_s.upcase)
      end
    end

    # Index table extension for showing translation status
    module IndexTableForExtension
      def translation_status
        column I18n.t("active_admin.globalize.translations", default: "Translations") do |obj|
          obj.translation_names.map do |t|
            '<span class="status_tag">%s</span>' % t
          end.join(" ").html_safe
        end
      end

      def translation_status_flags
        column I18n.t("active_admin.globalize.translations", default: "Translations") do |obj|
          obj.translations.map(&:locale).sort.map { |l| flag_icon(l) }.join(" ").html_safe
        end
      end

      private

      def flag_icon(locale)
        content_tag(:i, "", class: "flag flag-#{locale}", title: I18n.t("active_admin.globalize.language.#{locale}", default: locale.to_s.upcase))
      end
    end

    # View helper for flag icons
    module FlagHelper
      def flag_icon(locale)
        content_tag(:i, "", class: "flag flag-#{locale}", title: I18n.t("active_admin.globalize.language.#{locale}", default: locale.to_s.upcase))
      end
    end
  end
end

# Wire up the extensions
ActiveSupport.on_load(:active_record) do
  extend ActiveAdmin::GlobalizeTranslations::ActiveRecordExtension
end

# These need to be loaded after ActiveAdmin is initialized
Rails.application.config.after_initialize do
  if defined?(ActiveAdmin::FormBuilder)
    ActiveAdmin::FormBuilder.include ActiveAdmin::GlobalizeTranslations::FormBuilderExtension
  end

  if defined?(ActiveAdmin::Views::AttributesTable)
    ActiveAdmin::Views::AttributesTable.include ActiveAdmin::GlobalizeTranslations::AttributesTableExtension
  end

  if defined?(ActiveAdmin::Views::IndexAsTable::IndexTableFor)
    ActiveAdmin::Views::IndexAsTable::IndexTableFor.include ActiveAdmin::GlobalizeTranslations::IndexTableForExtension
  end

  if defined?(ActiveAdmin::ViewHelpers)
    ActiveAdmin::ViewHelpers.include ActiveAdmin::GlobalizeTranslations::FlagHelper
  end
end
