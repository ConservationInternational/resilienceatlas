# Script to verify migration results
puts "=== Remaining raster layers: #{Layer.where(layer_provider: "raster").count} ==="

puts "\n=== Sample migrated COG layers: ==="
Layer.where(layer_provider: "cog").where("layer_config LIKE ?", "%resilienceatlas.s3.dualstack%").limit(3).each do |l|
  puts "---"
  puts "ID: #{l.id}"
  puts "Name: #{l.name}"
  puts "Provider: #{l.layer_provider}"
  puts "Layer Config: #{l.layer_config}"
  puts ""
end

puts "\n=== Total COG layers (including newly migrated): #{Layer.where(layer_provider: "cog").count} ==="
