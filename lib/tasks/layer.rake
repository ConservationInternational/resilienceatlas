namespace :layers do

  desc "Deletes layers and layer groups and import new ones."
  task import: :environment do
    puts "\n This will delete your current layers from database and import the last backup, are you sure? [Y/N]"
    answer = STDIN.gets.chomp
    puts answer
    if answer == "Y"
      puts "Deleting layers..."
      Layer.delete_all
      LayerGroup.delete_all
      Agrupation.delete_all
      SiteScope.delete_all
      puts "Importing new layers..."
      filename = 'db/data/layers.rb'
      load(filename) if File.exist?(filename)
      ActiveRecord::Base.connection.reset_pk_sequence!('layers')
      ActiveRecord::Base.connection.reset_pk_sequence!('layer_groups')
      ActiveRecord::Base.connection.reset_pk_sequence!('agrupations')
      ActiveRecord::Base.connection.reset_pk_sequence!('site_scopes')
      puts "Layers imported."
    else
      puts "Nothing changed."
    end
  end

  desc "Creates a new export file with layers and layer groups."
  task backup: :environment do
    sh "bundle exec rake db:seed:dump FILE=db/data/layers.rb MODELS=layers,layer_groups,agrupations, site_scopes EXCLUDE=[]"
    puts "Backup created."
  end

  desc "Upgrades the layer / layer groups relations to many_to_many."
  task upgrade: :environment do
    if Agrupation.any?
      puts "Layer schema already upgraded."
    else
      Layer.all.each do |l|
        if l.layer_group_id.present?
          Agrupation.create!(layer_id: l.id, layer_group_id: l.layer_group_id)
        end
      end
      puts "Layers upgraded."
    end
  end
end
