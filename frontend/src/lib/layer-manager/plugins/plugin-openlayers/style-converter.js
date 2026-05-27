/**
 * VectorGrid-style PathOptions → OL Style converter.
 *
 * Allows existing martin/scope layer configs (written for Leaflet VectorGrid) to
 * be reused with OL VectorTileLayer without rewriting every layer config.
 *
 * PathOptions shape:
 *   { color, weight, opacity, fillColor, fillOpacity, fill, fillPattern }
 *
 * Extended PathOptions also support a `conditions` array for attribute-based
 * styling (converted from CartoDB conditional CSS rules):
 *   conditions: [{ when: { property: value }, ...overrides }, ...]
 * String equality: { when: { type: "hotspot" }, fillColor: "#abc" }
 * Numeric comparison: { when: { value: { op: "<=", val: 35 } }, fillColor: "#abc" }
 * All matching conditions are merged in order (CSS cascade: last match wins).
 *
 * fillPattern values:
 *   "hatch" - diagonal crosshatch canvas pattern using fillColor as line colour
 */
import Style from 'ol/style/Style';
import Stroke from 'ol/style/Stroke';
import Fill from 'ol/style/Fill';

function hexToRgba(hex, opacity) {
  // Expand 3-char shorthand (#FFF → #FFFFFF) before parsing
  const expanded = hex.replace(/^#?([a-f\d])([a-f\d])([a-f\d])$/i, '#$1$1$2$2$3$3');
  const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(expanded);
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

/** Cache of CanvasPattern objects keyed by "color:size" to avoid recreation. */
const hatchPatternCache = new Map();

/**
 * Create a repeating diagonal-crosshatch CanvasPattern in the given colour.
 * Matches the visual style of CartoDB's polygon-pattern-file hatching.
 *
 * @param {string} color - CSS colour string for the hatch lines
 * @param {number} [size=8] - Tile size in pixels
 * @returns {CanvasPattern|string} CanvasPattern in browser; solid colour string as SSR fallback
 */
function createHatchPattern(color, size = 8) {
  if (typeof document === 'undefined') return color; // SSR fallback
  const cacheKey = `${color}:${size}`;
  if (hatchPatternCache.has(cacheKey)) return hatchPatternCache.get(cacheKey);

  const canvas = document.createElement('canvas');
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext('2d');
  ctx.strokeStyle = color;
  ctx.lineWidth = 1.5;
  ctx.lineCap = 'square';

  // ╲ diagonal (seamless: extend slightly beyond tile boundary)
  ctx.beginPath();
  ctx.moveTo(-1, -1);
  ctx.lineTo(size + 1, size + 1);
  ctx.stroke();

  // ╱ diagonal
  ctx.beginPath();
  ctx.moveTo(size + 1, -1);
  ctx.lineTo(-1, size + 1);
  ctx.stroke();

  const pattern = ctx.createPattern(canvas, 'repeat');
  hatchPatternCache.set(cacheKey, pattern);
  return pattern;
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
        case '<=':
          return num <= spec.val;
        case '>=':
          return num >= spec.val;
        case '<':
          return num < spec.val;
        case '>':
          return num > spec.val;
        case '!=':
          return num !== spec.val;
        default:
          return false;
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
  let fillColorResolved = Object.prototype.hasOwnProperty.call(base, 'fillColor');
  for (const condition of conditions) {
    const { when, ...overrides } = condition;
    if (evaluateWhen(when, props)) {
      resolved = { ...resolved, ...overrides };
      if (Object.prototype.hasOwnProperty.call(overrides, 'fillColor')) fillColorResolved = true;
    }
  }

  // When conditions are present but no condition (or base) provided a fillColor,
  // suppress the fill. This matches CartoDB's behaviour: features that don't
  // satisfy any rule are invisible rather than defaulting to the stroke colour.
  if (!fillColorResolved) {
    resolved.fill = false;
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
    fillPattern,
  } = pathOptions;

  let fillStyle = null;
  if (fillPattern === 'hatch') {
    // Canvas crosshatch pattern: use fillColor as line colour at full opacity.
    const hatchColor = resolveColor(fillColor || color, 1);
    fillStyle = new Fill({ color: createHatchPattern(hatchColor) });
  } else if (fill || fillOpacity > 0) {
    fillStyle = new Fill({ color: resolveColor(fillColor || color, fillOpacity) });
  }

  return new Style({
    stroke: weight > 0 ? new Stroke({ color: resolveColor(color, opacity), width: weight }) : null,
    fill: fillStyle,
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
      typeof styleSpec === 'function' ? styleSpec(props) : resolveConditions(styleSpec, props);
    return pathOptionsToStyle(pathOptions);
  };
}
