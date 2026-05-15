import { replace } from '../../utils/query';
import TileLayer from 'ol/layer/Tile';
import XYZ from 'ol/source/XYZ';

/**
 * GEE (Google Earth Engine) tile layer handler for OpenLayers.
 *
 * Phase 1: Uses the static tile URL from layerConfig.body.url directly.
 * Phase 5a will add a backend proxy (GET /api/v1/gee/tile-url?layer_id=) that
 * issues fresh URLs with 55-minute caching, replacing the static approach.
 *
 * The current GEE tile URLs from the DB already contain the access token baked in.
 * Token refresh via 403-retry will be wired in when the backend proxy is available.
 */
const GEELayerOL = (layerModel) => {
  const { layerConfig, params, sqlParams } = layerModel;
  const layerConfigParsed =
    layerConfig.parse === false
      ? layerConfig
      : JSON.parse(replace(JSON.stringify(layerConfig), params, sqlParams));

  return new Promise((resolve) => {
    const { body } = layerConfigParsed;
    const { url, options = {} } = body;

    if (!url) {
      console.error('[GEE Layer OL] No tile URL in layerConfig.body.url');
      resolve(null);
      return;
    }

    const layer = new TileLayer({
      source: new XYZ({
        url,
        crossOrigin: 'anonymous',
        tileSize: options.tileSize || 256,
      }),
      opacity: layerModel.opacity ?? 1,
      zIndex: layerModel.zIndex,
      properties: { _provider: 'gee', _layerId: layerModel.id },
    });

    resolve(layer);
  });
};

GEELayerOL.getBounds = () => Promise.resolve(null);

export default GEELayerOL;
