ActiveAdmin.register LayerGroup do
  permit_params :name, :slug, :category, :active, :order, :info, :layer_group_type, :super_group_id, :icon_class,
    :site_scope_id, agrupations_attributes: [:layer_id, :id, :active, :_destroy],
    translations_attributes: [:id, :locale, :name, :info, :_destroy]

  member_action :duplicate, only: :show, method: :get do
    n = resource.clone!

    redirect_to edit_admin_layer_group_path(n)
  end

  form do |f|
    f.semantic_errors

    f.inputs "Translated fields" do
      f.translated_inputs switch_locale: false do |t|
        t.input :name
        t.input :info
      end
    end

    f.inputs "Layers" do
      f.has_many :agrupations, allow_destroy: true do |deg|
        deg.input :layer,
          as: :select,
          collection: Layer.with_translations.sort_by(&:name).map { |l| ["#{l.name} - id: #{l.id}", l.id] }
        deg.input :active
      end
      f.input :site_scope
    end
    f.inputs "Layer Group Details" do
      f.input :slug
      # f.input :category
      f.input :active
      f.input :order
      f.input :layer_group_type, as: :select, collection: %w[group category subcategory subgroup]
      f.input :super_group,
        as: :select,
        collection: begin
          site_scope_id = f.object.site_scope_id || 1
          LayerGroup.with_translations
            .where(site_scope_id: site_scope_id)
            .sort_by(&:name)
            .map { |lg| ["#{lg.name} - #{lg.id}", lg.id] }
        end,
        input_html: {"data-site-scope-groups": LayerGroup.with_translations.group_by(&:site_scope_id).transform_values { |groups|
          groups.sort_by(&:name).map { |lg| {id: lg.id, name: "#{lg.name} - #{lg.id}"} }
        }.to_json}
      # f.input :icon_class
      f.actions
    end

    f.inputs do
      script_tag = <<~JAVASCRIPT
        <script type="text/javascript">
          $(document).ready(function() {
            var siteScopeGroupsData = $('#layer_group_super_group_id').data('site-scope-groups');
            
            function updateSuperGroupOptions(siteScope) {
              var superGroupSelect = $('#layer_group_super_group_id');
              var currentValue = superGroupSelect.val();
              
              // Clear existing options except the blank one
              superGroupSelect.find('option').not(':first').remove();
              
              // Get groups for the selected site scope
              var groups = siteScopeGroupsData[siteScope] || [];
              
              // Add new options
              groups.forEach(function(group) {
                var option = $('<option></option>')
                  .attr('value', group.id)
                  .text(group.name);
                superGroupSelect.append(option);
              });
              
              // Restore the previous value if it's still available
              if (currentValue && superGroupSelect.find('option[value="' + currentValue + '"]').length > 0) {
                superGroupSelect.val(currentValue);
              }
            }
            
            // Update when site scope changes
            $('#layer_group_site_scope_id').on('change', function() {
              var selectedSiteScope = $(this).val();
              if (selectedSiteScope) {
                updateSuperGroupOptions(selectedSiteScope);
              }
            });
            
            // Initialize on page load
            var initialSiteScope = $('#layer_group_site_scope_id').val();
            if (initialSiteScope) {
              updateSuperGroupOptions(initialSiteScope);
            }
          });
        </script>
      JAVASCRIPT
      
      f.template.content_tag(:div, script_tag.html_safe)
    end
  end
  index do
    selectable_column
    column :id
    column :name
    column :layer_group_type
    column :site_scope do |lg|
      SiteScope.find(lg.site_scope_id).name if lg.site_scope_id.present?
    end
    column :layers do |lg|
      lg.layers.map { |l| l.name }.join(", ")
    end
    column :order
    column :updated_at
    actions defaults: true do |layer_group|
      link_to "Duplicate", duplicate_admin_layer_group_path(layer_group)
    end
  end
end
