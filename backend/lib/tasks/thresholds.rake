namespace :thresholds do
  desc <<~DESC
    Seed the SBTN Planetary Boundaries (thresholds) site scope.

    Prefer running the full setup script which handles CSV acquisition and
    CartoDB upload automatically:

      ./scripts/setup_thresholds_data.sh

    This rake task is a lower-level fallback for when the CSV is already
    present and the CartoDB table has been uploaded manually.
  DESC
  task seed: :environment do
    load Rails.root.join("db/data/thresholds/seed.rb")
    ThresholdsSeeder.run
  end
end
