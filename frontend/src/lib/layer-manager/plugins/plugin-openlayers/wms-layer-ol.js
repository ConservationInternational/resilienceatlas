import { replace } from '../../utils/query';
import TileLayer from 'ol/layer/Tile';
import TileWMS from 'ol/source/TileWMS';

/**
 * WMS layer handler for OpenLayers (dedicated provider: 'wms').
 *
 * layerConfig.body:
 *   url: WMS service endpoint
 *   params: { LAYERS, VERSION, FORMAT, TRANSPARENT, ... }
 */
const WMSLayerOL = (layerModel) => {
  const { layerConfig, params, sqlParams } = layerModel;
  const layerConfigParsed =
    layerConfig.parse === false
      ? layerConfig
      : JSON.parse(replace(JSON.stringify(layerConfig), params, sqlParams));

  return new Promise((resolve) => {
    const { body } = layerConfigParsed;
    const { url, params: wmsParams = {} } = body;

    if (!url) {
      console.error('[WMS Layer OL] No url in layerConfig.body');
      resolve(null);
      return;
    }

    const layer = new TileLayer({
      source: new TileWMS({
        url,
        params: {
          VERSION: '1.3.0',
          FORMAT: 'image/png',
          TRANSPARENT: true,
          ...wmsParams,
        },
        crossOrigin: 'anonymous',
      }),
      opacity: layerModel.opacity ?? 1,
      zIndex: layerModel.zIndex,
      properties: { _provider: 'wms', _layerId: layerModel.id },
    });

    resolve(layer);
  });
};

WMSLayerOL.getBounds = () => Promise.resolve(null);

export default WMSLayerOL;
