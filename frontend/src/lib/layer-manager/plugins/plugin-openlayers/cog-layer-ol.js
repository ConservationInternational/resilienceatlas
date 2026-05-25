import { fetchCogBounds, CANCELED } from '../../services/cog-service';
import { replace } from '../../utils/query';
import { getTitilerBaseUrl } from '../../../../utilities/environment';
import LayerGroup from 'ol/layer/Group';
import TileLayer from 'ol/layer/Tile';
import XYZ from 'ol/source/XYZ';

/**
 * Build the TiTiler tile URL from layer config (identical logic to cog-layer-leaflet).
 * COG tiles go directly browser → TiTiler (bypassing Rails), CloudFront-cached.
 */
function buildSingleTitilerUrl(layerConfig, sourceOverride) {
  const { body } = layerConfig;
  if (body.url && !sourceOverride) return body.url;

  const source = sourceOverride || body.source;
  const { colormap, colormap_name, bidx, nodata, rescale, resampling_method } = body;
  if (!source) {
    console.error('[COG Layer OL] No source URL in layerConfig.body');
    return null;
  }

  const titilerBaseUrl = getTitilerBaseUrl();
  let tileUrl = `${titilerBaseUrl}/tiles/WebMercatorQuad/{z}/{x}/{y}?url=${encodeURIComponent(source)}`;
  if (bidx) tileUrl += `&bidx=${bidx}`;
  if (resampling_method) tileUrl += `&resampling_method=${resampling_method}`;
  if (nodata !== undefined && nodata !== null) tileUrl += `&nodata=${nodata}`;
  // Interval colormaps (arrays) use raw pixel values directly in TiTiler.
  // Passing rescale alongside them would pre-normalise values to 0-255 and
  // break the interval matching, so rescale is omitted for that format.
  const isIntervalColormap = Array.isArray(colormap);
  if (rescale && !isIntervalColormap) tileUrl += `&rescale=${encodeURIComponent(rescale)}`;
  if (colormap_name) {
    tileUrl += `&colormap_name=${encodeURIComponent(colormap_name)}`;
  } else if (
    colormap &&
    (isIntervalColormap ? colormap.length > 0 : Object.keys(colormap).length > 0)
  ) {
    tileUrl += `&colormap=${encodeURIComponent(JSON.stringify(colormap))}`;
  }
  // Clip raster tiles to the boundary geometry stored during migration.
  // This replaces CartoDB's ST_CLIP — TiTiler renders only within the feature polygon.
  if (body.clip_geometry) {
    tileUrl += `&feature=${encodeURIComponent(JSON.stringify(body.clip_geometry))}`;
  }
  return tileUrl;
}

function buildTitilerUrls(layerConfig) {
  const { body } = layerConfig;
  const sources =
    Array.isArray(body.sources) && body.sources.length > 0 ? body.sources : [body.source];
  return sources.map((source) => buildSingleTitilerUrl(layerConfig, source)).filter(Boolean);
}

/**
 * COG layer handler for OpenLayers.
 * Uses TiTiler for tile generation (same as Leaflet version).
 */
const CogLayerOL = (layerModel) => {
  const { layerConfig, params, sqlParams } = layerModel;
  const layerConfigParsed =
    layerConfig.parse === false
      ? layerConfig
      : JSON.parse(replace(JSON.stringify(layerConfig), params, sqlParams));

  return new Promise((resolve) => {
    const urls = buildTitilerUrls(layerConfigParsed);
    if (urls.length === 0) {
      console.error('[COG Layer OL] Failed to build tile URL');
      resolve(null);
      return;
    }

    const { body } = layerConfigParsed;
    const { options = {} } = body;

    const tileLayers = urls.map(
      (url) =>
        new TileLayer({
          source: new XYZ({
            url,
            crossOrigin: 'anonymous',
            tileSize: options.tileSize || 256,
          }),
          properties: { _provider: 'cog', _layerId: layerModel.id },
        }),
    );

    const layer =
      tileLayers.length === 1
        ? tileLayers[0]
        : new LayerGroup({
            layers: tileLayers,
            properties: { _provider: 'cog', _layerId: layerModel.id },
          });

    layer.setOpacity(layerModel.opacity ?? 1);
    layer.setZIndex(layerModel.zIndex);

    resolve(layer);
  });
};

CogLayerOL.getBounds = (layerModel) => {
  return fetchCogBounds(layerModel)
    .then((bounds) => {
      if (bounds === CANCELED) return null;
      return bounds;
    })
    .catch((error) => {
      console.warn('[COG Layer OL] Failed to fetch bounds:', error);
      return null;
    });
};

export default CogLayerOL;
