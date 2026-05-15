import { fetchCogBounds, CANCELED } from '../../services/cog-service';
import { replace } from '../../utils/query';
import { getTitilerBaseUrl } from '../../../../utilities/environment';
import TileLayer from 'ol/layer/Tile';
import XYZ from 'ol/source/XYZ';

/**
 * Build the TiTiler tile URL from layer config (identical logic to cog-layer-leaflet).
 * COG tiles go directly browser → TiTiler (bypassing Rails), CloudFront-cached.
 */
function buildTitilerUrl(layerConfig) {
  const { body } = layerConfig;
  if (body.url) return body.url;

  const { source, colormap, colormap_name, bidx, nodata } = body;
  if (!source) {
    console.error('[COG Layer OL] No source URL in layerConfig.body');
    return null;
  }

  const titilerBaseUrl = getTitilerBaseUrl();
  let tileUrl = `${titilerBaseUrl}/tiles/WebMercatorQuad/{z}/{x}/{y}?url=${encodeURIComponent(source)}`;
  if (bidx) tileUrl += `&bidx=${bidx}`;
  if (nodata !== undefined && nodata !== null) tileUrl += `&nodata=${nodata}`;
  if (colormap_name) {
    tileUrl += `&colormap_name=${encodeURIComponent(colormap_name)}`;
  } else if (colormap && Object.keys(colormap).length > 0) {
    tileUrl += `&colormap=${encodeURIComponent(JSON.stringify(colormap))}`;
  }
  return tileUrl;
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
    const url = buildTitilerUrl(layerConfigParsed);
    if (!url) {
      console.error('[COG Layer OL] Failed to build tile URL');
      resolve(null);
      return;
    }

    const { body } = layerConfigParsed;
    const { options = {} } = body;

    const layer = new TileLayer({
      source: new XYZ({
        url,
        crossOrigin: 'anonymous',
        tileSize: options.tileSize || 256,
      }),
      opacity: layerModel.opacity ?? 1,
      zIndex: layerModel.zIndex,
      properties: { _provider: 'cog', _layerId: layerModel.id },
    });

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
