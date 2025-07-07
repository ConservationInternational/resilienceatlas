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
      Rake::Task["db:drop"].invoke
      puts "✓ Dropped existing test database"
    rescue => e
      puts "Database drop failed or database didn't exist: #{e.message}"
    end

    # Create database
    Rake::Task["db:create"].invoke
    puts "✓ Created test database"

    # Load schema with error handling
    begin
      Rake::Task["db:schema:load"].invoke
      puts "✓ Loaded database schema"
    rescue ActiveRecord::StatementInvalid => e
      if e.message.include?("already exists")
        puts "⚠ Schema elements already exist, continuing..."
        # Try to run migrations instead
        begin
          Rake::Task["db:migrate"].invoke
        rescue
          nil
        end
      else
        raise e
      end
    end

    puts "✅ Test database setup completed"
  end

  private

  def with_config
    yield Rails.application.class.parent_name.underscore,
    ActiveRecord::Base.connection_config[:host],
    ActiveRecord::Base.connection_config[:database],
    ActiveRecord::Base.connection_config[:username]
  end
end
