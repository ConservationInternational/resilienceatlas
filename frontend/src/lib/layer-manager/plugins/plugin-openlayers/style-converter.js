/**
 * VectorGrid-style PathOptions → OL Style converter.
 *
 * Allows existing martin/scope layer configs (written for Leaflet VectorGrid) to
 * be reused with OL VectorTileLayer without rewriting every layer config.
 *
 * PathOptions shape:
 *   { color, weight, opacity, fillColor, fillOpacity, fill }
 *
 * Extended PathOptions also support a `conditions` array for attribute-based
 * styling (converted from CartoDB conditional CSS rules):
 *   conditions: [{ when: { property: value }, ...overrides }, ...]
 * String equality: { when: { type: "hotspot" }, fillColor: "#abc" }
 * Numeric comparison: { when: { value: { op: "<=", val: 35 } }, fillColor: "#abc" }
 * All matching conditions are merged in order (CSS cascade: last match wins).
 */
import Style from 'ol/style/Style';
import Stroke from 'ol/style/Stroke';
import Fill from 'ol/style/Fill';

function hexToRgba(hex, opacity) {
  const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
  if (!result) return `rgba(0,0,0,${opacity ?? 1})`;
  return `rgba(${parseInt(result[1], 16)},${parseInt(result[2], 16)},${parseInt(result[3], 16)},${opacity ?? 1})`;
}

function resolveColor(color, opacity) {
  if (!color) return `rgba(51,136,255,${opacity ?? 1})`;
  if (color.startsWith('#')) return hexToRgba(color, opacity);
  // Named colors or rgb()/rgba() — wrap opacity as-is
  if (color.startsWith('rgba') || color.startsWith('rgb')) return color;
  return color;
}

/**
 * Evaluate a single `when` condition against feature properties.
 *
 * Each entry in `when` is either:
 *   - a plain string/number for equality:   { type: "hotspot area" }
 *   - an operator object for comparisons:   { value: { op: "<=", val: 35 } }
 *
 * @param {object} when - Condition descriptor
 * @param {object} props - Feature properties
 * @returns {boolean}
 */
function evaluateWhen(when, props) {
  return Object.entries(when).every(([key, spec]) => {
    if (spec !== null && typeof spec === 'object' && spec.op !== undefined) {
      const num = parseFloat(props[key]);
      if (Number.isNaN(num)) return false;
      switch (spec.op) {
        case '<=': return num <= spec.val;
        case '>=': return num >= spec.val;
        case '<':  return num < spec.val;
        case '>':  return num > spec.val;
        case '!=': return num !== spec.val;
        default:   return false;
      }
    }
    // String / strict equality
    return String(props[key]) === String(spec);
  });
}

/**
 * Resolve any `conditions` in a PathOptions object against feature properties.
 * Returns a plain PathOptions object (without the `conditions` key).
 *
 * Conditions are evaluated in declaration order and ALL matching conditions
 * are merged (later declarations override earlier ones), matching the CSS
 * cascade. This correctly handles overlapping numeric range rules such as
 * choropleth `[value <= 90]` / `[value <= 35]` / `[value <= 0]` selectors.
 *
 * @param {object} pathOptions - PathOptions, possibly with a `conditions` array
 * @param {object} props - Feature properties from feature.getProperties()
 * @returns {object} Resolved PathOptions without `conditions`
 */
function resolveConditions(pathOptions, props) {
  const { conditions, ...base } = pathOptions;
  if (!conditions || !conditions.length) return base;

  let resolved = { ...base };
  for (const condition of conditions) {
    const { when, ...overrides } = condition;
    if (evaluateWhen(when, props)) {
      resolved = { ...resolved, ...overrides };
    }
  }
  return resolved;
}

/**
 * Convert a single PathOptions object to an OL Style.
 * @param {object} pathOptions - Leaflet/VectorGrid PathOptions
 * @returns {import('ol/style/Style').default}
 */
export function pathOptionsToStyle(pathOptions) {
  if (!pathOptions) return new Style();
  const {
    color = '#3388ff',
    weight = 3,
    opacity = 1,
    fillColor,
    fillOpacity = 0.2,
    fill = true,
  } = pathOptions;

  return new Style({
    stroke: weight > 0 ? new Stroke({ color: resolveColor(color, opacity), width: weight }) : null,
    fill:
      fill || fillOpacity > 0
        ? new Fill({ color: resolveColor(fillColor || color, fillOpacity) })
        : null,
  });
}

/**
 * Build an OL StyleFunction from a VectorGrid vectorTileLayerStyles map.
 *
 * @param {object|function} styles - VectorGrid styles: object keyed by MVT layer name,
 *   where each value is either a PathOptions object or a (properties) => PathOptions function.
 * @returns {function} OL StyleFunction: (feature) => Style
 */
export function buildVectorTileStyle(styles) {
  if (!styles) return undefined;

  if (typeof styles === 'function') {
    // Called as a single style function (not keyed by layer name)
    return (feature) => pathOptionsToStyle(styles(feature.getProperties()));
  }

  return (feature) => {
    const layerName = feature.get('layer');
    const styleSpec = styles[layerName];
    if (!styleSpec) return null;
    const props = feature.getProperties();
    const pathOptions =
      typeof styleSpec === 'function'
        ? styleSpec(props)
        : resolveConditions(styleSpec, props);
    return pathOptionsToStyle(pathOptions);
  };
}
