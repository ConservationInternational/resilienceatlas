class EnableFuzzystrmatchExtension < ActiveRecord::Migration[7.2]
  def up
    enable_extension "fuzzystrmatch" unless extension_enabled?("fuzzystrmatch")
  end

  def down
    disable_extension "fuzzystrmatch"
  end
end
