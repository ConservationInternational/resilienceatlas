ActiveAdmin.register SiteScope do
  includes :translations

  permit_params :subdomain, :color, :has_analysis, :latitude, :longitude, :header_theme, :zoom_level,
    :linkback_url, :header_color, :logo_url, :predictive_model, :analysis_options, :has_gef_logo,
    :password_protected, :username, :password,
    translations_attributes: [:id, :locale, :name, :linkback_text, :_destroy]

  # Log validation errors for debugging
  controller do
    def create
      super do |success, failure|
        failure.html do
          Rails.logger.error "SiteScope validation errors: #{resource.errors.full_messages.inspect}"
          render :new
        end
      end
    end
  end

  filter :layer_groups, as: :select, collection: proc { LayerGroup.with_translations.map { |m| [m.name, m.id] } }
  filter :site_pages, as: :select, collection: proc { SitePage.with_translations.map { |m| [m.title, m.id] } }
  filter :translations_name_eq, as: :select, label: "Name", collection: proc { SiteScope.with_translations.pluck(:name) }
  filter :subdomain
  filter :has_analysis
  filter :predictive_model
  filter :analysis_options
  filter :has_gef_logo
  filter :password_protected
  filter :latitude
  filter :longitude

  member_action :duplicate, only: :show, method: :get do
    n = resource.clone!

    redirect_to edit_admin_site_scope_path(n)
  end

  form do |f|
    f.semantic_errors :password, :username, *f.object.errors.attribute_names

    f.inputs "Translated fields" do
      f.translated_inputs switch_locale: false do |ff|
        ff.input :name
        ff.input :linkback_text
      end
    end

    f.inputs "Site scope fields" do
      f.input :color
      f.input :header_theme, as: :select, collection: %w[ci-theme vs-theme]
      f.input :header_color, as: :color
      f.input :logo_url, as: :string
      f.input :subdomain
      f.input :has_analysis
      f.input :linkback_url, as: :string
      f.input :predictive_model
      f.input :analysis_options
      f.input :has_gef_logo, label: "Has GEF logo"
    end

    f.inputs "Password Protection" do
      f.input :password_protected, as: :boolean, label: "Enable password protection"
      f.input :username, label: "Username (required if password protected)",
        hint: "Username for accessing this site scope"

      # Show current password if set (with visibility toggle)
      if f.object.encrypted_password.present?
        current_password = f.object.viewable_password
        if current_password.present?
          li class: "input optional current-password-wrapper" do
            label "Current Password", class: "label", for: "current_site_scope_password"
            div class: "password-input-container", style: "display: flex; align-items: center; gap: 10px;" do
              text_node "<input type='password' value='#{ERB::Util.html_escape(current_password)}' id='current_site_scope_password' class='password-toggle-field current-password-display' readonly style='flex: 1; background-color: #f9f9f9; padding: 8px; border: 1px solid #ccc; border-radius: 4px;'><button type='button' onclick=\"var f=document.getElementById('current_site_scope_password');if(f.type==='password'){f.type='text';this.textContent='Hide';}else{f.type='password';this.textContent='Show';}return false;\" style='padding: 6px 12px; cursor: pointer; border: 1px solid #ccc; border-radius: 4px; background: #f5f5f5;'>Show</button>".html_safe
            end
          end
        else
          # Fallback if viewable password is not available (legacy data)
          li class: "input optional current-password-wrapper" do
            label "Current Password", class: "label"
            div class: "password-status" do
              span "✓ Password is set (stored before viewing was enabled)", class: "password-set-indicator password-legacy"
            end
          end
        end
      end

      # New/change password field
      has_password_error = f.object.errors[:password].present?
      li class: "input optional password-field-wrapper #{"error" if has_password_error}" do
        label_text = f.object.encrypted_password.present? ? "New Password" : "Password"
        placeholder_text = f.object.encrypted_password.present? ? "Leave blank to keep current password" : "Enter password (min 6 characters)"
        hint_text = f.object.encrypted_password.present? ? "Leave blank to keep the existing password. Enter a new password (minimum 6 characters) to change it." : "Minimum 6 characters."

        label label_text, for: "site_scope_password", class: "label"
        div class: "password-input-container", style: "display: flex; align-items: center; gap: 10px;" do
          text_node "<input type='password' name='site_scope[password]' id='site_scope_password' class='password-toggle-field' placeholder='#{ERB::Util.html_escape(placeholder_text)}' style='flex: 1; padding: 8px; border: 1px solid #ccc; border-radius: 4px;#{" border-color: #c00;" if has_password_error}'><button type='button' onclick=\"var f=document.getElementById('site_scope_password');if(f.type==='password'){f.type='text';this.textContent='Hide';}else{f.type='password';this.textContent='Show';}return false;\" style='padding: 6px 12px; cursor: pointer; border: 1px solid #ccc; border-radius: 4px; background: #f5f5f5;'>Show</button>".html_safe
        end
        # Display password validation errors inline
        if has_password_error
          f.object.errors[:password].each do |error|
            para error, class: "inline-errors", style: "color: #c00; margin-top: 5px;"
          end
        end
        para hint_text, class: "inline-hints"
      end
    end

    f.inputs "Location", {data: {geousable: "yes"}} do
      f.input :latitude, input_html: {class: "lat"}
      f.input :longitude, input_html: {class: "lng"}
      f.input :zoom_level
    end

    f.actions
  end

  index do
    selectable_column

    column :name
    column :subdomain
    column :color
    column :header_theme
    column :has_analysis
    column :password_protected

    actions defaults: true do |site_scope|
      link_to "Duplicate", duplicate_admin_site_scope_path(site_scope)
    end
  end

  show do
    attributes_table do
      row :id
      row :name
      row :color
      row :header_theme
      row :header_color
      row :logo_url
      row :subdomain
      row :has_analysis
      row :linkback_text
      row :linkback_url
      row :predictive_model
      row :analysis_options
      row :has_gef_logo
      row :password_protected
      row :username
      row("Password") do |site_scope|
        if site_scope.encrypted_password.present?
          viewable_pwd = site_scope.viewable_password
          if viewable_pwd.present?
            "<div style='display: flex; align-items: center; gap: 10px;'><input type='password' value='#{ERB::Util.html_escape(viewable_pwd)}' id='show_site_scope_password' readonly style='border: 1px solid #ccc; padding: 6px 10px; border-radius: 4px; background-color: #f9f9f9;'><button type='button' onclick=\"var f=document.getElementById('show_site_scope_password');if(f.type==='password'){f.type='text';this.textContent='Hide';}else{f.type='password';this.textContent='Show';}return false;\" style='padding: 6px 12px; cursor: pointer; border: 1px solid #ccc; border-radius: 4px; background: #f5f5f5;'>Show</button></div>".html_safe
          else
            content_tag(:span, "Password set (stored before viewing was enabled)", class: "password-legacy-notice")
          end
        else
          "Not set"
        end
      end
      row :latitude
      row :longitude
      row :zoom_level
    end
  end
end
