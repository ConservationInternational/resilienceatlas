require_relative "../tile_security_import_task"

namespace :layers do
  desc "Deletes layers and layer groups and import new ones."
  task import: :environment do
    puts "\n This will delete your current layers from database and import the last backup, are you sure? [Y/N]"
    answer = $stdin.gets.chomp
    puts answer
    if answer == "Y"
      restrictions = Layer.where("data_policy = 'restricted' OR (security_provenance = 'explicit' AND NOT public_data)")
        .pluck(:slug, :data_policy).to_h
      restricted_sources = Layer.where(slug: restrictions.keys).filter_map { |layer| TileSecurityPolicy.new(layer).source_key }
      protected_scopes = SiteScope.where(password_protected: true).to_h do |scope|
        [scope.subdomain, scope.attributes.slice("username", "encrypted_password", "encrypted_viewable_password")]
      end
      puts "Deleting layers..."
      Agrupation.delete_all
      Layer.delete_all
      LayerGroup.delete_all
      SiteScope.delete_all
      puts "Importing new layers..."
      filename = "db/data/layers.rb"
      load(filename) if File.exist?(filename)
      protected_scopes.each do |subdomain, credentials|
        SiteScope.find_by(subdomain: subdomain)&.update_columns(credentials.merge("password_protected" => true))
      end
      # Backups are configuration, not trusted approval or generation state.
      Layer.find_each do |layer|
        restricted = restrictions.key?(layer.slug) || layer.data_policy == "restricted" ||
          restricted_sources.include?(TileSecurityPolicy.new(layer).source_key)
        layer.update_columns(public_data: false, tile_cache_version: SecureRandom.hex(16),
          data_policy: restricted ? "restricted" : "public",
          security_provenance: restricted ? "explicit" : "default_public")
      end
      ActiveRecord::Base.connection.reset_pk_sequence!("layers")
      ActiveRecord::Base.connection.reset_pk_sequence!("layer_groups")
      ActiveRecord::Base.connection.reset_pk_sequence!("agrupations")
      ActiveRecord::Base.connection.reset_pk_sequence!("site_scopes")
      puts "Layers imported."
    else
      puts "Nothing changed."
    end
  end

  desc "Creates a new export file with layers and layer groups."
  task backup: :environment do
    sh "bundle exec rake db:seed:dump FILE=db/data/layers.rb MODELS=layers,layer_groups,agrupations,site_scopes EXCLUDE=[]"
    puts "Backup created."
  end

  desc "Upgrades the layer / layer groups relations to many_to_many."
  task upgrade: :environment do
    if Agrupation.any?
      puts "Layer schema already upgraded."
    else
      LayerGroup.update_all(site_scope_id: 1)
      Layer.all.each do |l|
        if l.layer_group_id.present?
          Agrupation.create!(layer_id: l.id, layer_group_id: l.layer_group_id)
        end
      end
      puts "Layers upgraded."
    end
  end

  desc "Delete generated zip files in download folder"
  task delete_downloads: :environment do
    FileUtils.rm_rf(Dir.glob("downloads/*"))
    puts "Downloads deleted."
  end
end

TileSecurityImportTask.wrap("layers:import", "layers:upgrade")
