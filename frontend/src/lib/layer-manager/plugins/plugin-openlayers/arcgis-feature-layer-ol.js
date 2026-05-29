import { replace } from '../../utils/query';
import VectorLayer from 'ol/layer/Vector';
import VectorSource from 'ol/source/Vector';
import EsriJSON from 'ol/format/EsriJSON';
import { tile as tileStrategy } from 'ol/loadingstrategy';
import { createXYZ } from 'ol/tilegrid';

/**
 * ArcGIS FeatureServer vector layer handler for OpenLayers.
 *
 * Loads features from ArcGIS REST FeatureServer using EsriJSON format.
 * Uses tiled loading strategy for performance with large datasets.
 *
 * layerConfig.body:
 *   url: FeatureServer URL (e.g., .../FeatureServer/0)
 *   params: optional query params (where, outFields, etc.)
 *   options: optional layer options (style, etc.)
 *
 * Example layer_config:
 * {
 *   "body": {
 *     "url": "https://services.arcgis.com/.../FeatureServer/0",
 *     "params": {
 *       "where": "1=1",
 *       "outFields": "*"
 *     }
 *   }
 * }
 */
const ArcGISFeatureLayerOL = (layerModel) => {
  const { layerConfig, params, sqlParams } = layerModel;
  const layerConfigParsed =
    layerConfig.parse === false
      ? layerConfig
      : JSON.parse(replace(JSON.stringify(layerConfig), params, sqlParams));

  return new Promise((resolve) => {
    const { body } = layerConfigParsed;
    const { url, params: serviceParams = {} } = body;

    if (!url) {
      console.error('[ArcGIS Feature Layer OL] No url in layerConfig.body');
      resolve(null);
      return;
    }

    const esriFormat = new EsriJSON();

    const vectorSource = new VectorSource({
      format: esriFormat,
      url: (extent, _resolution, _projection) => {
        // Build query URL for tiled loading
        // ArcGIS REST API query endpoint expects specific parameters
        const baseParams = {
          f: 'json',
          returnGeometry: 'true',
          spatialRel: 'esriSpatialRelIntersects',
          geometry: JSON.stringify({
            xmin: extent[0],
            ymin: extent[1],
            xmax: extent[2],
            ymax: extent[3],
            spatialReference: { wkid: 3857 },
          }),
          geometryType: 'esriGeometryEnvelope',
          inSR: '3857',
          outFields: serviceParams.outFields || '*',
          outSR: '3857',
          ...serviceParams,
        };

        const queryString = new URLSearchParams(baseParams).toString();
        return `${url}/query?${queryString}`;
      },
      strategy: tileStrategy(
        createXYZ({
          tileSize: 512,
        }),
      ),
    });

    const layer = new VectorLayer({
      source: vectorSource,
      opacity: layerModel.opacity ?? 1,
      zIndex: layerModel.zIndex,
      properties: { _provider: 'arcgis_feature', _layerId: layerModel.id },
    });

    resolve(layer);
  });
};

ArcGISFeatureLayerOL.getBounds = () => Promise.resolve(null);

export default ArcGISFeatureLayerOL;
