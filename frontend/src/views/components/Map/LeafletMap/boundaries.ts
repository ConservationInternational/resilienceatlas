/**
 * Admin boundary vector tile layer using PostGIS-generated MVT tiles.
 *
 * The backend serves protobuf vector tiles at /api/boundary-tiles/{z}/{x}/{y}
 * with scale-dependent rendering:
 *   zoom 0-4:  ADM0 (countries)
 *   zoom 5-7:  ADM0 + ADM1 (provinces/states)
 *   zoom 8+:   ADM0 + ADM1 + ADM2 (districts)
 *
 * Requires leaflet.vectorgrid to be loaded before this module is used
 * (it is bootstrapped in Map.component.tsx alongside other Leaflet plugins).
 */
import L from 'leaflet';

/**
 * Build the tile URL template for boundary MVT tiles.
 * Uses the configured API host or falls back to a relative URL.
 */
function getBoundaryTileUrl(): string {
  const apiHost = process.env.NEXT_PUBLIC_API_HOST || '';
  // If apiHost is set and looks like a full URL, use it; otherwise use relative path
  const base = apiHost && apiHost.startsWith('http') ? apiHost : '';
  return `${base}/api/boundary-tiles/{z}/{x}/{y}`;
}

/**
 * Style function for boundary features.
 * Returns thicker lines for higher-level admin units.
 */
function boundaryStyle(properties: { admin_level?: number }): L.PathOptions {
  const level = properties.admin_level ?? 0;
  return {
    weight: level === 0 ? 1.6 : level === 1 ? 1.0 : 0.6,
    color: level === 0 ? '#444' : level === 1 ? '#666' : '#888',
    opacity: level === 0 ? 0.9 : level === 1 ? 0.7 : 0.5,
    fill: false,
    interactive: false,
  };
}

/**
 * Creates a Leaflet VectorGrid layer that renders admin boundary MVT tiles.
 *
 * @returns A Leaflet layer instance (VectorGrid.Protobuf) ready to be added to the map.
 */
export function createBoundaryTileLayer(): L.Layer {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const VectorGrid = (L as any).vectorGrid;

  if (!VectorGrid) {
    console.warn('leaflet.vectorgrid is not loaded — boundary tiles unavailable');
    return L.layerGroup(); // return empty layer as fallback
  }

  return VectorGrid.protobuf(getBoundaryTileUrl(), {
    vectorTileLayerStyles: {
      // 'boundaries' matches the MVT layer name set in AdminBoundary.mvt_tile
      boundaries: (properties: { admin_level?: number }) => boundaryStyle(properties),
    },
    maxNativeZoom: 13,
    pane: 'overlayPane',
  });
}
