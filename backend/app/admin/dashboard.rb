# frozen_string_literal: true

ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: proc { I18n.t("active_admin.dashboard") }

  content title: proc { I18n.t("active_admin.dashboard") } do
    if current_admin_user.superadmin?

      # ─── Section A: Google Analytics ─────────────────────────────────────────
      ga = GoogleAnalyticsService.new

      panel "Google Analytics" do
        # Always show the "Open Google Analytics" link regardless of config state
        div style: "margin-bottom: 18px;" do
          a "Open Google Analytics →",
            href: ga.analytics_url,
            target: "_blank",
            style: "display: inline-block; padding: 8px 18px; background: #4285F4; color: #fff; border-radius: 4px; text-decoration: none; font-weight: bold; font-size: 14px;"
        end

        if ga.configured?
          ga_data = ga.fetch_summary(days: 30)

          if ga_data
            columns do
              column do
                div style: "text-align: center; padding: 16px 0;" do
                  h2 number_with_delimiter(ga_data[:metrics][:sessions]),
                    style: "font-size: 2.8em; margin: 0; color: #4285F4; font-weight: bold;"
                  para "Sessions", style: "color: #666; margin: 4px 0 0;"
                  small "(last 30 days)"
                end
              end
              column do
                div style: "text-align: center; padding: 16px 0;" do
                  h2 number_with_delimiter(ga_data[:metrics][:active_users]),
                    style: "font-size: 2.8em; margin: 0; color: #34A853; font-weight: bold;"
                  para "Active Users", style: "color: #666; margin: 4px 0 0;"
                  small "(last 30 days)"
                end
              end
              column do
                div style: "text-align: center; padding: 16px 0;" do
                  h2 number_with_delimiter(ga_data[:metrics][:page_views]),
                    style: "font-size: 2.8em; margin: 0; color: #EA4335; font-weight: bold;"
                  para "Page Views", style: "color: #666; margin: 4px 0 0;"
                  small "(last 30 days)"
                end
              end
            end

            if ga_data[:top_pages].any?
              h3 "Top Pages (last 30 days)", style: "margin-top: 20px; margin-bottom: 8px;"
              table_for ga_data[:top_pages] do
                column("Page Path") { |row| row[:path] }
                column("Views") { |row| number_with_delimiter(row[:views]) }
              end
            end

            div style: "margin-top: 10px; color: #999; font-size: 12px;" do
              text_node "Cached data · last fetched #{ga_data[:fetched_at].strftime("%b %d %Y, %H:%M UTC")}"
            end
          else
            div style: "padding: 12px; background: #fff3cd; border-left: 4px solid #ffc107; border-radius: 2px;" do
              para "Unable to retrieve Google Analytics data. Check that your service account credentials are valid and have Analytics Viewer access.",
                style: "margin: 0; color: #856404;"
            end
          end
        else
          div style: "padding: 16px; background: #f8f9fa; border-left: 4px solid #4285F4; border-radius: 2px;" do
            h3 "Google Analytics Not Configured", style: "margin-top: 0; color: #333;"
            para "Set these environment variables on the server to enable live analytics data:"
            ul do
              li do
                code "GA4_PROPERTY_ID"
                text_node " — numeric GA4 property ID (e.g. 123456789)"
              end
              li do
                code "GOOGLE_APPLICATION_CREDENTIALS_JSON"
                text_node " — service account JSON with Analytics Viewer access, as a single-line string"
              end
            end
            para do
              text_node "Create a service account in the "
              a "Google Cloud Console", href: "https://console.cloud.google.com/iam-admin/serviceaccounts", target: "_blank"
              text_node ", then grant it "
              em "Viewer"
              text_node " access in GA4 Admin → Property Access Management."
            end
          end
        end
      end

      # ─── Section B: Overview counts ──────────────────────────────────────────
      total_site_scopes = SiteScope.count
      total_layers = Layer.count
      published_layers = Layer.where(published: true).count
      total_users = User.count
      new_users_30d = User.where("created_at >= ?", 30.days.ago).count
      total_scope_datasets = ScopeDataset.count

      panel "Overview" do
        columns do
          column do
            div style: "text-align: center; padding: 16px 0;" do
              h2 total_site_scopes.to_s, style: "font-size: 3em; margin: 0; color: #333; font-weight: bold;"
              para "Site Scopes", style: "color: #666; margin: 4px 0 0; font-weight: bold;"
            end
          end
          column do
            div style: "text-align: center; padding: 16px 0;" do
              h2 total_layers.to_s, style: "font-size: 3em; margin: 0; color: #333; font-weight: bold;"
              para "Layers", style: "color: #666; margin: 4px 0 0; font-weight: bold;"
              small "#{published_layers} published · #{total_layers - published_layers} unpublished"
            end
          end
          column do
            div style: "text-align: center; padding: 16px 0;" do
              h2 total_users.to_s, style: "font-size: 3em; margin: 0; color: #333; font-weight: bold;"
              para "Users", style: "color: #666; margin: 4px 0 0; font-weight: bold;"
              small "+#{new_users_30d} registered last 30 days"
            end
          end
          column do
            div style: "text-align: center; padding: 16px 0;" do
              h2 total_scope_datasets.to_s, style: "font-size: 3em; margin: 0; color: #333; font-weight: bold;"
              para "Scope Datasets", style: "color: #666; margin: 4px 0 0; font-weight: bold;"
            end
          end
        end
      end

      # ─── Section C: Content breakdown ────────────────────────────────────────
      columns do
        column do
          panel "Layers by Type" do
            layer_type_data = Layer.group(:layer_type).order(Arel.sql("COUNT(*) DESC")).count
            if layer_type_data.any?
              text_node column_chart(layer_type_data, height: "280px", colors: ["#3498db"],
                library: {scales: {y: {ticks: {stepSize: 1}}}})
            else
              para "No layers found.", style: "color: #999;"
            end
          end
        end
        column do
          panel "Top Site Scopes by Layer Count" do
            scope_counts = SiteScope
              .joins(layer_groups: :layers)
              .group("site_scopes.subdomain")
              .order(Arel.sql("COUNT(layers.id) DESC"))
              .limit(8)
              .count("layers.id")
            if scope_counts.any?
              table_for scope_counts.to_a do
                column("Subdomain") { |row| row[0] }
                column("Layers") { |row| row[1] }
              end
            else
              para "No site scope layer data available.", style: "color: #999;"
            end
          end
        end
      end

      # ─── Section D: User activity ─────────────────────────────────────────────
      columns do
        column do
          panel "New User Registrations (last 90 days)" do
            reg_data = User.group_by_day(:created_at, last: 90).count
            if reg_data.values.sum > 0
              text_node line_chart(reg_data, height: "250px", colors: ["#2ecc71"])
            else
              para "No new registrations in the last 90 days.", style: "color: #999;"
            end
          end
        end
        column do
          panel "Recently Active Users" do
            recent_users = User.where.not(last_sign_in_at: nil)
              .order(last_sign_in_at: :desc)
              .limit(7)
            if recent_users.any?
              table_for recent_users do
                column(:email)
                column("Organization") { |u| u.organization.presence || "—" }
                column("Sign-ins") { |u| u.sign_in_count }
                column("Last Sign-in") { |u| u.last_sign_in_at.strftime("%b %d, %Y") }
              end
            else
              para "No user sign-in activity yet.", style: "color: #999;"
            end
          end
        end
      end

      # ─── Section E: Downloads & Data Imports ──────────────────────────────────
      columns do
        column do
          panel "Downloads (last 30 days)" do
            dl_data = UserDownload.group_by_day(:created_at, last: 30).count
            if dl_data.values.sum > 0
              text_node line_chart(dl_data, height: "250px", colors: ["#e74c3c"])
            else
              para "No downloads in the last 30 days.", style: "color: #999;"
            end
          end
        end
        column do
          panel "Data Imports" do
            total_bytes = DataImport.sum(:file_size_bytes).to_i
            status_counts = DataImport.group(:status).count
            total_rows = DataImport.sum(:rows_imported).to_i

            formatted_size = if total_bytes >= 1.gigabyte
              "#{(total_bytes.to_f / 1.gigabyte).round(2)} GB"
            elsif total_bytes >= 1.megabyte
              "#{(total_bytes.to_f / 1.megabyte).round(1)} MB"
            elsif total_bytes > 0
              "#{(total_bytes.to_f / 1.kilobyte).round(1)} KB"
            else
              "0 KB"
            end

            table_for [
              {label: "Total Storage Imported", value: formatted_size},
              {label: "Total Rows Imported", value: number_with_delimiter(total_rows)},
              {label: "Completed Imports", value: status_counts["complete"] || 0},
              {label: "Pending / Processing", value: status_counts["pending"].to_i + status_counts["processing"].to_i},
              {label: "Failed Imports", value: status_counts["failed"] || 0}
            ] do
              column("") { |row| row[:label] }
              column("") { |row| row[:value] }
            end

            recent_imports = DataImport.includes(:admin_user).order(created_at: :desc).limit(5)
            if recent_imports.any?
              h3 "Recent Imports", style: "margin-top: 16px; margin-bottom: 8px;"
              table_for recent_imports do
                column("File") { |d| d.file_name }
                column("Type") { |d| d.import_type }
                column("Size") { |d| d.formatted_file_size }
                column("Status") { |d| d.status }
                column("Date") { |d| d.created_at.strftime("%b %d, %Y") }
              end
            end
          end
        end
      end

    else
      # Non-superadmin: simple welcome message
      div class: "blank_slate_container", id: "dashboard_default_message" do
        span class: "blank_slate" do
          span "Welcome to the Resilience Atlas Admin"
          small "Choose from the menu the resource you wish to edit"
        end
      end
    end
  end
end
