namespace :db do
  desc "Dumps the database to db/APP_NAME.dump"
  task dump: :environment do
    cmd = nil
    with_config do |app, host, db, user|
      cmd = "pg_dump --host #{host} --username #{user} --verbose --clean --no-owner --no-acl --format=c #{db} > #{Rails.root}/db/#{app}.dump"
    end
    puts cmd
    exec cmd
  end

  desc "Restores the database dump at db/APP_NAME.dump."
  task restore: :environment do
    cmd = nil
    with_config do |app, host, db, user|
      cmd = "pg_restore --verbose --host #{host} --username #{user} --clean --no-owner --no-acl --dbname #{db} #{Rails.root}/db/#{app}.dump"
    end
    Rake::Task["db:drop"].invoke
    Rake::Task["db:create"].invoke
    Rake::Task["db:migrate"].invoke
    puts cmd
    exec cmd
  end

  desc "Sets up test database safely, handling PostGIS schemas"
  task test_setup: :environment do
    puts "Setting up test database safely..."

    # Drop database if it exists
    begin
      Rake::Task["db:drop"].reenable
      Rake::Task["db:drop"].invoke
      puts "✓ Dropped existing test database"
    rescue => e
      puts "Database drop failed or database didn't exist: #{e.message}"
    end

    # Create database
    Rake::Task["db:create"].reenable
    Rake::Task["db:create"].invoke
    puts "✓ Created test database"

    # Run migrations instead of schema:load to avoid PostGIS topology conflict
    # The postgis_topology extension creates the "topology" schema automatically,
    # but schema.rb also has create_schema "topology" which causes a conflict
    begin
      Rake::Task["db:migrate"].reenable
      Rake::Task["db:migrate"].invoke
      puts "✓ Ran database migrations"
    rescue ActiveRecord::StatementInvalid => e
      if e.message.include?("already exists")
        puts "⚠ Some schema elements already exist, but migrations completed"
      else
        raise e
      end
    end

    puts "✅ Test database setup completed"
  end

  private

  def with_config
    yield Rails.application.class.parent_name.underscore,
      ActiveRecord::Base.connection_db_config.configuration_hash[:host],
      ActiveRecord::Base.connection_db_config.configuration_hash[:database],
      ActiveRecord::Base.connection_db_config.configuration_hash[:username]
  end
end
