/**
 * Admin boundary vector tile layers served by Martin.
 *
 * Renders ADM0/ADM1/ADM2 boundaries using OL VectorTile with two stacked layers:
 *   - halo layer: wide semi-transparent white line for contrast
 *   - line layer: main boundary lines
 *
 * Martin serves MVT from the `boundary_tiles` function source at
 * /boundary_tiles/{z}/{x}/{y} with scale-dependent admin levels.
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

function getBoundaryTileUrl(): string {
  const martinUrl = process.env.NEXT_PUBLIC_MARTIN_URL;
  if (!martinUrl) {
    // eslint-disable-next-line no-console
    console.warn('NEXT_PUBLIC_MARTIN_URL is not set — boundary tiles will be unavailable');
    return '';
  }
  return `${martinUrl}/boundary_tiles/{z}/{x}/{y}`;
}

function lineStyle(feature: FeatureLike): Style {
  const level = (feature.get('admin_level') as number) ?? 0;
  const widths = [1.6, 1.0, 0.6];
  const colors = ['#444', '#666', '#888'];
  const opacities = [0.9, 0.7, 0.5];
  const idx = Math.min(level, 2);
  return new Style({
    stroke: new Stroke({
      color: `rgba(${hexToRgb(colors[idx])},${opacities[idx]})`,
      width: widths[idx],
    }),
  });
}

function haloStyle(feature: FeatureLike): Style {
  const level = (feature.get('admin_level') as number) ?? 0;
  const widths = [2.5, 2.0, 1.0];
  const opacities = [0.35, 0.25, 0.2];
  const idx = Math.min(level, 2);
  return new Style({
    stroke: new Stroke({
      color: `rgba(255,255,255,${opacities[idx]})`,
      width: widths[idx],
    }),
  });
}

function hexToRgb(hex: string): string {
  const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
  if (!result) return '0,0,0';
  return `${parseInt(result[1], 16)},${parseInt(result[2], 16)},${parseInt(result[3], 16)}`;
}

/**
 * Returns [haloLayer, lineLayer] for admin boundary rendering.
 * Both share the same VectorTile source.
 */
export function createBoundaryLayers(): VectorTileLayer[] {
  const tileUrl = getBoundaryTileUrl();
  if (!tileUrl) return [];

  const source = new VectorTileSource({
    url: tileUrl,
    format: new MVT(),
    maxZoom: 13,
  });

  const haloLayer = new VectorTileLayer({
    source,
    style: haloStyle,
    zIndex: 1100,
    properties: { _systemLayer: true },
  });

  const lineLayer = new VectorTileLayer({
    source,
    style: lineStyle,
    zIndex: 1101,
    properties: { _systemLayer: true },
  });

  return [haloLayer, lineLayer];
}
