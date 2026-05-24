# CartoDB CSS to MapLibre Conversion - Bug Fixes

## Issues Identified

### Issue 1: Missing Default Line Width for Base Rule

**Problem**: When the base CartoDB CSS rule has `line-color` but no `line-width`, the conversion did not apply CartoDB's default 1px line width. This is inconsistent with how conditional rules are processed, which DO apply the default.

**Example CSS that failed**:
```css
#layer {
  polygon-fill: #0080ff;
  line-color: #FFF;  /* White border specified */
  /* line-width missing - should default to 1px */
}
#layer [value <= 100] {
  polygon-fill: #ff4d4d;
}
```

**Before fix**: Border would not render properly (undefined weight)
**After fix**: Border renders with 1.0px width (CartoDB default)

**Code location**: `backend/lib/tasks/cartodb.rake` lines 1023-1029

**Fix applied**:
```ruby
# Before (lines 1023-1024):
path_opts["color"] = base_props["line-color"] if base_props["line-color"].present?
path_opts["weight"] = base_props["line-width"].to_f if base_props["line-width"].present?

# After (lines 1023-1031):
path_opts["color"] = base_props["line-color"] if base_props["line-color"].present?
# Stroke weight: use explicit value, or CartoDB default (1 px) when a
# stroke colour is declared but no width is specified.
if base_props["line-width"].present?
  path_opts["weight"] = base_props["line-width"].to_f
elsif base_props["line-color"].present?
  path_opts["weight"] = 1.0
end
```

### Issue 2: Invisible Base Guard Removes Strokes from Conditional Rules

**Problem**: When a layer has ONLY conditional rules (no base styling), the "invisible base" guard would set `weight: 0`, making polygon borders invisible even when the conditional rules specify `line-color`. This caused polygons to appear with black borders (OpenLayers default) or no borders at all.

**Example CSS that failed**:
```css
/* No base rule - only conditionals */
#layer [value <= 100] {
  polygon-fill: #B10026;
  line-color: #B10026;  /* Should render red border */
}
#layer [value <= 50] {
  polygon-fill: #FFFFB2;
  line-color: #FFFFB2;  /* Should render yellow border */
}
```

**Before fix**: Base weight set to 0, conditional line-colors ignored → black borders
**After fix**: Base weight NOT set to 0 when conditionals have strokes → correct colored borders

**Code location**: `backend/lib/tasks/cartodb.rake` lines 1117-1129

**Fix applied**:
```ruby
# Before (lines 1117-1120):
if path_opts["conditions"]&.any? && (path_opts.keys - ["conditions"]).empty?
  path_opts = {"fill" => false, "fillOpacity" => 0, "weight" => 0}.merge(path_opts)
end

# After (lines 1119-1131):
if path_opts["conditions"]&.any? && (path_opts.keys - ["conditions"]).empty?
  # Check if any conditional rules have line-color (they would provide stroke)
  has_conditional_stroke = path_opts["conditions"].any? do |cond|
    cond.key?("color") || cond.key?("weight")
  end
  
  invisible_base = {"fill" => false, "fillOpacity" => 0}
  invisible_base["weight"] = 0 unless has_conditional_stroke
  path_opts = invisible_base.merge(path_opts)
end
```

## Testing

To test these fixes on actual layers, run the migration task:

```bash
# Re-process Martin vector layers to update their styles
docker compose -f docker-compose.dev.yml run --rm backend \
  rake cartodb:update_layer_references[martin,true]
```

This will re-translate all CartoDB CSS → MapLibre styles with the bug fixes applied.

## Expected Results

After applying these fixes:

1. **Narrow white borders**: Layers like "Top crops by production" (id: 3) with `line-color: #FFF; line-width: 0.5;` will correctly render thin white borders around polygons.

2. **Conditional line colors**: Layers like "Women illiteracy" (id: 26, 44) that have only conditional styling with line-color will render with properly colored borders instead of black.

3. **Data-driven colors**: Layers like those showing Tanzania data will correctly display color-coded polygons with appropriate borders instead of appearing all black.

## Files Modified

- `backend/lib/tasks/cartodb.rake` - Two bug fixes in `translate_vector_css` method

## Verification

Compare staging (with bugs) vs production (original CartoDB):
- Staging: https://staging.resilienceatlas.org/map/...
- Production: https://resilienceatlas.org/map/...

After fixes, staging should match production's polygon border styling.
