namespace :sites do

  desc "Initialize site scopes."
  task reset: :environment do
    puts "\n This will delete your current site scopes from database and create the original ones, are you sure? [Y/N]"
    answer = STDIN.gets.chomp
    puts answer
    if answer == "Y"
      puts "Deleting site scopes..."
      SiteScope.delete_all
      puts "Creating site scopes..."
      SiteScope.create!(name: 'CIGRP', id: 1)
      SiteScope.create!(name: 'Indicators', id: 2, subdomain: 'indicators')
      SiteScope.create!(name: 'Tanzania', id: 3, subdomain: 'atlas.tanzania')
      SiteScope.create!(name: 'Ghana', id: 4, subdomain: 'atlas.ghana')
      SiteScope.create!(name: 'Uganda', id: 5, subdomain: 'atlas.uganda')
      SiteScope.create!(name: 'Rwanda', id: 6, subdomain: 'atlas.rwanda')
      SiteScope.create!(name: 'Amazonia', id: 7, subdomain: 'amazonia')
      SiteScope.create!(name: 'test', id: 8, subdomain: 'test')
      ActiveRecord::Base.connection.reset_pk_sequence!('site_scopes')
      puts "Site scopes created."
    else
      puts "Nothing changed."
    end
  end
end
