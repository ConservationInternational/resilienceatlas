import { replace } from '../../utils/query';
import VectorTileLayer from 'ol/layer/VectorTile';
import VectorTileSource from 'ol/source/VectorTile';
import MVT from 'ol/format/MVT';
import { buildVectorTileStyle } from './style-converter';

/**
 * Martin PostGIS vector tile layer handler for OpenLayers.
 *
 * Expects layerConfig.body:
 *   source: Martin source name (PostGIS table or function), e.g. "my_table"
 *   styles: VectorGrid-compatible styles object keyed by MVT layer name
 *   options: Optional extra layer options (maxNativeZoom, etc.)
 *   mapboxStyle: Optional Mapbox GL style JSON (used instead of styles when present)
 */
const MartinLayerOL = (layerModel) => {
  const martinUrl = process.env.NEXT_PUBLIC_MARTIN_URL;
  if (!martinUrl) throw new Error('NEXT_PUBLIC_MARTIN_URL is not configured.');

  const { layerConfig, params, sqlParams } = layerModel;
  const layerConfigParsed =
    layerConfig.parse === false
      ? layerConfig
      : JSON.parse(replace(JSON.stringify(layerConfig), params, sqlParams));

  return new Promise((resolve) => {
    const { body } = layerConfigParsed;
    const { source, styles, options = {} } = body;

    const tileUrl = `${martinUrl}/${source}/{z}/{x}/{y}`;

    const vectorTileSource = new VectorTileSource({
      url: tileUrl,
      format: new MVT(),
      maxZoom: options.maxNativeZoom ?? 14,
    });

    const layer = new VectorTileLayer({
      source: vectorTileSource,
      style: styles ? buildVectorTileStyle(styles) : undefined,
      opacity: layerModel.opacity ?? 1,
      zIndex: layerModel.zIndex,
      properties: { _provider: 'martin', _layerId: layerModel.id, _isVectorTile: true },
    });

    resolve(layer);
  });
};

MartinLayerOL.getBounds = () => Promise.resolve(null);

export default MartinLayerOL;
