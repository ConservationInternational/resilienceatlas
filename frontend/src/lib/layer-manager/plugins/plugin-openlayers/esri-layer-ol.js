import { replace } from '../../utils/query';
import TileLayer from 'ol/layer/Tile';
import TileArcGISRest from 'ol/source/TileArcGISRest';

/**
 * ESRI ArcGIS REST tile service handler for OpenLayers.
 *
 * Supports Map/Tile services via ol/source/TileArcGISRest.
 * For Feature Services (vector), use arcgis_feature provider (separate handler).
 *
 * layerConfig.body:
 *   url: ArcGIS REST service URL
 *   params: optional params (layers, dpi, etc.)
 */
const EsriLayerOL = (layerModel) => {
  const { layerConfig, params, sqlParams } = layerModel;
  const layerConfigParsed =
    layerConfig.parse === false
      ? layerConfig
      : JSON.parse(replace(JSON.stringify(layerConfig), params, sqlParams));

  return new Promise((resolve) => {
    const { body } = layerConfigParsed;
    const { url, params: serviceParams = {} } = body;

    if (!url) {
      console.error('[ESRI Layer OL] No url in layerConfig.body');
      resolve(null);
      return;
    }

    const layer = new TileLayer({
      source: new TileArcGISRest({
        url,
        params: serviceParams,
        crossOrigin: 'anonymous',
      }),
      opacity: layerModel.opacity ?? 1,
      zIndex: layerModel.zIndex,
      properties: { _provider: 'esri', _layerId: layerModel.id },
    });

    resolve(layer);
  });
};

EsriLayerOL.getBounds = () => Promise.resolve(null);

export default EsriLayerOL;
