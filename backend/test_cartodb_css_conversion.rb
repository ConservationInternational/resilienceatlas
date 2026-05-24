# Test script for CartoDB CSS to PathOptions conversion
# Run with: docker compose -f docker-compose.dev.yml run --rm backend rails runner test_cartodb_css_conversion.rb

# Load the rake tasks helpers
require_relative "lib/tasks/cartodb.rake"

def float_matches?(actual, expected)
  (actual.to_f - expected).abs < 1e-9
end

# Test cases
test_cases = [
  {
    name: "Base with white border + conditional fills (should preserve white border)",
    css: "#layer{polygon-fill:#0080ff;polygon-opacity:0.8;line-color:#FFF;line-width:0.5;line-opacity:1;}#layer[value<=100]{polygon-fill:#ff4d4d;}#layer[value<=50]{polygon-fill:#0080ff;}"
  },
  {
    name: "Base with line-color but NO line-width (should default to 1px)",
    css: "#layer{polygon-fill:#0080ff;line-color:#FFF;}#layer[value<=100]{polygon-fill:#ff4d4d;}"
  },
  {
    name: "Only line-width:0 in base, all styling in conditionals (should have colored borders)",
    css: "#layer{line-width:0;}#layer[value<=100]{polygon-fill:#D64A00;polygon-opacity:1;}#layer[value<75]{polygon-fill:#FF8700;polygon-opacity:1;}"
  },
  {
    name: "No base styling, only conditionals with line-color (should have borders)",
    css: "#layer[value<=100]{polygon-fill:#B10026;line-color:#B10026;}#layer[value<=50]{polygon-fill:#FFFFB2;line-color:#FFFFB2;}"
  }
]

puts "=" * 80
puts "CartoDB CSS Conversion Tests"
puts "=" * 80

test_cases.each_with_index do |test, idx|
  puts "\nTest #{idx + 1}: #{test[:name]}"
  puts "-" * 80

  result = CartodbRakeHelpers.translate_vector_css(test[:css])

  puts "Base properties:"
  base_props = result.except("conditions")
  base_props.each do |key, value|
    puts "  #{key}: #{value.inspect}"
  end

  if result["conditions"]
    puts "\nConditional rules: #{result["conditions"].size} rules"
    result["conditions"].first(2).each_with_index do |condition, condition_index|
      puts "  Condition #{condition_index + 1}:"
      condition.each do |key, value|
        next if key == "when"

        puts "    #{key}: #{value.inspect}"
      end
    end
  end

  # Validate expectations
  puts "\nValidation:"
  case idx
  when 0
    if result["color"] == "#FFF" && float_matches?(result["weight"], 0.5)
      puts "  ✓ White border preserved (color: #FFF, weight: 0.5)"
    else
      puts "  ✗ FAILED: Expected white 0.5px border, got color: #{result["color"]}, weight: #{result["weight"]}"
    end
  when 1
    if result["color"] == "#FFF" && float_matches?(result["weight"], 1.0)
      puts "  ✓ Default weight applied (color: #FFF, weight: 1.0)"
    else
      puts "  ✗ FAILED: Expected white 1.0px border, got color: #{result["color"]}, weight: #{result["weight"]}"
    end
  when 2
    if float_matches?(result["weight"], 0.0)
      puts "  ✓ Base weight is 0 as specified"
    else
      puts "  ✗ FAILED: Expected base weight: 0, got: #{result["weight"]}"
    end

    if result["conditions"]&.any?
      puts "  ✓ Has #{result["conditions"].size} conditional rules for polygon fills"
    else
      puts "  ✗ FAILED: Expected conditional rules"
    end
  when 3
    has_stroke = result["conditions"]&.any? { |condition| condition["color"].present? && condition["weight"].present? }
    if has_stroke
      sample_condition = result["conditions"].find { |condition| condition["color"].present? }
      puts "  ✓ Conditional rules have line-color and default weight (sample: color=#{sample_condition["color"]}, weight=#{sample_condition["weight"]})"
    else
      puts "  ✗ FAILED: Expected conditional rules to have stroke styling"
    end

    if result["weight"] != 0
      puts "  ✓ Base weight not set to 0 (conditionals will provide strokes)"
    else
      puts "  ✗ FAILED: Base weight should not be 0 when conditionals have strokes"
    end
  end
end

puts "\n" + "=" * 80
puts "Tests complete"
puts "=" * 80
