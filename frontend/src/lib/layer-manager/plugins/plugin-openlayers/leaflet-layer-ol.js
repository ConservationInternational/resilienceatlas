import { replace } from '../../utils/query';
import TileLayer from 'ol/layer/Tile';
import XYZ from 'ol/source/XYZ';
import TileWMS from 'ol/source/TileWMS';

/**
 * Generic tile layer handler for OpenLayers.
 * Handles XYZ tile layers and simple WMS (detected by URL or type hint).
 *
 * layerConfig.body:
 *   url: tile URL template or WMS service URL
 *   type: 'tileLayer' (default) | 'wms'
 *   params: for WMS: { LAYERS, VERSION, FORMAT, ... }
 */
const LeafletLayerOL = (layerModel) => {
  const { layerConfig, params, sqlParams } = layerModel;
  const layerConfigParsed =
    layerConfig.parse === false
      ? layerConfig
      : JSON.parse(replace(JSON.stringify(layerConfig), params, sqlParams));

  return new Promise((resolve) => {
    const { body } = layerConfigParsed;
    const { url, type = 'tileLayer', params: wmsParams = {} } = body;

    const isWMS =
      type === 'wms' || (typeof url === 'string' && url.toLowerCase().includes('service=wms'));

    const layer = isWMS
      ? new TileLayer({
          source: new TileWMS({
            url,
            params: { VERSION: '1.3.0', FORMAT: 'image/png', TRANSPARENT: true, ...wmsParams },
            crossOrigin: 'anonymous',
          }),
          opacity: layerModel.opacity ?? 1,
          zIndex: layerModel.zIndex,
          properties: { _provider: 'leaflet', _layerId: layerModel.id },
        })
      : new TileLayer({
          source: new XYZ({ url, crossOrigin: 'anonymous' }),
          opacity: layerModel.opacity ?? 1,
          zIndex: layerModel.zIndex,
          properties: { _provider: 'leaflet', _layerId: layerModel.id },
        });

    resolve(layer);
  });
};

LeafletLayerOL.getBounds = () => Promise.resolve(null);

export default LeafletLayerOL;
