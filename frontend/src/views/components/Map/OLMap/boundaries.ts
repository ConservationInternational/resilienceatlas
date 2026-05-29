/**
 * Admin boundary vector tile layers served by Mapbox Streets V4 API.
 *
 * Renders ADM0/ADM1/ADM2 boundaries using OL VectorTile with two stacked layers:
 *   - halo layer: wide semi-transparent line for contrast
 *   - line layer: main boundary lines
 *
 * Mapbox Streets serves MVT from the V4 Vector Tiles API at
 * /v4/mapbox.mapbox-streets-v8/{z}/{x}/{y}.mvt with admin source-layer.
 *
 * Z-index layering order (bottom to top):
 *   0: Basemap
 *   ≤1000: Data layers (capped at 1000)
 *   1050: Admin preview layers
 *   1100-1101: Admin boundaries (halo, line)
 *   1110: Label overlay
 *   1200: Scope geometry layers
 *   2000-2001: Drawing manager
 *   9999-10002: Map compare controls
 */
import VectorTileLayer from 'ol/layer/VectorTile';
import VectorTileSource from 'ol/source/VectorTile';
import MVT from 'ol/format/MVT';
import Style from 'ol/style/Style';
import Stroke from 'ol/style/Stroke';
import type { FeatureLike } from 'ol/Feature';

const MAPBOX_ACCESS_TOKEN =
  'pk.eyJ1IjoiY2lncnAiLCJhIjoiYTQ5YzVmYTk4YzM0ZWM4OTU1ZjQxMWI5ZDNiNTQ5M2IifQ.SBgo9jJftBDx4c5gX4wm3g';

function getBoundaryTileUrl(): string {
  return `https://api.mapbox.com/v4/mapbox.mapbox-streets-v8/{z}/{x}/{y}.mvt?access_token=${MAPBOX_ACCESS_TOKEN}`;
}

type BoundaryStyle = 'light' | 'dark';

function createStyleFunction(
  boundaryStyle: BoundaryStyle,
  isHalo: boolean
): (feature: FeatureLike) => Style | null {
  // Light colors: for dark backgrounds/satellite imagery
  // Dark colors: for light backgrounds
  const lightColors = isHalo
    ? { halo: ['#ffffff', '#eeeeee', '#dddddd'], line: ['#f0f0f0', '#e0e0e0', '#d0d0d0'] }
    : { halo: ['#ffffff', '#eeeeee', '#dddddd'], line: ['#f0f0f0', '#e0e0e0', '#d0d0d0'] };
  const darkColors = isHalo
    ? { halo: ['#000000', '#222222', '#333333'], line: ['#666666', '#888888', '#aaaaaa'] }
    : { halo: ['#000000', '#222222', '#333333'], line: ['#666666', '#888888', '#aaaaaa'] };

  const colors = boundaryStyle === 'light' ? lightColors : darkColors;
  const colorSet = isHalo ? colors.halo : colors.line;

  return (feature: FeatureLike): Style | null => {
    // Filter to admin source-layer only
    const sourceLayer = feature.get('layer');
    if (sourceLayer !== 'admin') return null;

    // Skip maritime boundaries
    const maritime = feature.get('maritime');
    if (maritime === 1) return null;

    const level = (feature.get('admin_level') as number) ?? 0;
    const idx = Math.min(level, 2);

    // Zoom-dependent rendering would go here if needed
    // For now, rely on Mapbox's tile content

    const widths = isHalo ? [2.5, 2.0, 1.0] : [1.2, 0.8, 0.5];
    const opacities = isHalo ? [0.35, 0.25, 0.2] : [0.7, 0.6, 0.5];

    return new Style({
      stroke: new Stroke({
        color: `${colorSet[idx]}${Math.round(opacities[idx] * 255)
          .toString(16)
          .padStart(2, '0')}`,
        width: widths[idx],
      }),
    });
  };
}

/**
 * Returns [haloLayer, lineLayer] for admin boundary rendering.
 * Both share the same VectorTile source from Mapbox Streets.
 *
 * @param boundaryStyle - 'light' for light borders (dark backgrounds), 'dark' for dark borders (light backgrounds)
 */
export function createBoundaryLayers(boundaryStyle: BoundaryStyle = 'light'): VectorTileLayer[] {
  const tileUrl = getBoundaryTileUrl();
  if (!tileUrl) return [];

  const source = new VectorTileSource({
    url: tileUrl,
    format: new MVT(),
    maxZoom: 14,
  });

  const haloLayer = new VectorTileLayer({
    source,
    style: createStyleFunction(boundaryStyle, true),
    zIndex: 1100,
    properties: { _systemLayer: true },
  });

  const lineLayer = new VectorTileLayer({
    source,
    style: createStyleFunction(boundaryStyle, false),
    zIndex: 1101,
    properties: { _systemLayer: true },
  });

  return [haloLayer, lineLayer];
}
