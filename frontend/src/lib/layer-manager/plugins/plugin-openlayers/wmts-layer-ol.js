import { replace } from '../../utils/query';
import TileLayer from 'ol/layer/Tile';
import WMTSSource from 'ol/source/WMTS';
import WMTSTileGrid from 'ol/tilegrid/WMTS';
import { get as getProjection } from 'ol/proj';
import { getTopLeft, getWidth } from 'ol/extent';

/**
 * WMTS layer handler for OpenLayers.
 *
 * layerConfig.body:
 *   url: WMTS tile URL template (with {TileMatrix}/{TileCol}/{TileRow})
 *   layer: WMTS layer identifier
 *   matrixSet: e.g. "EPSG:3857" or "GoogleMapsCompatible"
 *   format: e.g. "image/png"
 *   style: WMTS style name (default: "default")
 *   projection: EPSG code (default: "EPSG:3857")
 *   resolutions: optional custom resolution array
 *   matrixIds: optional custom matrixIds array
 */
const WMTSLayerOL = (layerModel) => {
  const { layerConfig, params, sqlParams } = layerModel;
  const layerConfigParsed =
    layerConfig.parse === false
      ? layerConfig
      : JSON.parse(replace(JSON.stringify(layerConfig), params, sqlParams));

  return new Promise((resolve) => {
    const { body } = layerConfigParsed;
    const {
      url,
      layer,
      matrixSet = 'EPSG:3857',
      format = 'image/png',
      style = 'default',
      projection: projCode = 'EPSG:3857',
    } = body;

    if (!url || !layer) {
      console.error('[WMTS Layer OL] url and layer are required in layerConfig.body');
      resolve(null);
      return;
    }

    const projection = getProjection(projCode);
    const projExtent = projection.getExtent();
    const startResolution = getWidth(projExtent) / 256;
    const resolutions = Array.from({ length: 22 }, (_, i) => startResolution / Math.pow(2, i));
    const matrixIds = resolutions.map((_, i) => `${i}`);

    const tileGrid = new WMTSTileGrid({
      origin: getTopLeft(projExtent),
      resolutions,
      matrixIds,
    });

    const wmtsSource = new WMTSSource({
      url,
      layer,
      matrixSet,
      format,
      style,
      projection,
      tileGrid,
      crossOrigin: 'anonymous',
    });

    const olLayer = new TileLayer({
      source: wmtsSource,
      opacity: layerModel.opacity ?? 1,
      zIndex: layerModel.zIndex,
      properties: { _provider: 'wmts', _layerId: layerModel.id },
    });

    resolve(olLayer);
  });
};

WMTSLayerOL.getBounds = () => Promise.resolve(null);

export default WMTSLayerOL;
