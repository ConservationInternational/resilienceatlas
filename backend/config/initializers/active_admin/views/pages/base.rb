# frozen_string_literal: true

module ActiveAdmin
  module Views
    module Pages
      class Base < Arbre::HTML::Document
        private

        def build_active_admin_head
          within head do
            html_title [title, helpers.active_admin_namespace.site_title(self)].compact.join(" | ")

            text_node(active_admin_namespace.head)

            active_admin_application.stylesheets.each do |style, options|
              stylesheet_tag = active_admin_namespace.use_webpacker ? stylesheet_pack_tag(style, **options) : stylesheet_link_tag(style, **options)
              text_node(stylesheet_tag.html_safe) if stylesheet_tag
            end

            active_admin_namespace.meta_tags.each do |name, content|
              text_node(meta(name: name, content: content))
            end

            # Ensure importmap is loaded for Rails UJS support
            text_node javascript_importmap_tags

            active_admin_application.javascripts.each do |path|
              # -------- MONKEY PATCH -----------
              javascript_tag = insert_importmap_for path # active_admin_namespace.use_webpacker ? javascript_pack_tag(path) : javascript_include_tag(path)
              # ---------------------------------
              text_node(javascript_tag) if javascript_tag
            end

            if active_admin_namespace.favicon
              favicon = active_admin_namespace.favicon
              favicon_tag = active_admin_namespace.use_webpacker ? favicon_pack_tag(favicon) : favicon_link_tag(favicon)
              text_node(favicon_tag)
            end

            text_node csrf_meta_tag
          end
        end

        def insert_importmap_for(path)
          return javascript_importmap_tags "active_admin" if path == "active_admin.js"

          javascript_include_tag path if path.is_a?(String) && path&.match?(URI::DEFAULT_PARSER.make_regexp)
        end
      end
    end
  end
end
