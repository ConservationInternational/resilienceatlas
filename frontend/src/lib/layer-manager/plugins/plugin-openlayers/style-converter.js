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
 * The first matching condition's overrides are merged into the base PathOptions.
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
 * Resolve any `conditions` in a PathOptions object against feature properties.
 * Returns a plain PathOptions object (without the `conditions` key).
 *
 * @param {object} pathOptions - PathOptions, possibly with a `conditions` array
 * @param {object} props - Feature properties from feature.getProperties()
 * @returns {object} Resolved PathOptions without `conditions`
 */
function resolveConditions(pathOptions, props) {
  const { conditions, ...base } = pathOptions;
  if (!conditions || !conditions.length) return base;

  for (const condition of conditions) {
    const { when, ...overrides } = condition;
    const matches = Object.entries(when).every(
      ([key, val]) => String(props[key]) === String(val)
    );
    if (matches) return { ...base, ...overrides };
  }
  return base;
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
