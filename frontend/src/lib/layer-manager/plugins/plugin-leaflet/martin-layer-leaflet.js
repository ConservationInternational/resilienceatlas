import { replace } from '../../utils/query';

const getL = () => (typeof window !== 'undefined' ? window.L : undefined);

/**
 * Martin vector tile layer handler.
 *
 * Expects layerConfig.body to contain:
 *   - source:  Martin source name (PostGIS table or function), e.g. "my_table"
 *   - styles:  Optional vectorTileLayerStyles object keyed by MVT layer name
 *   - options: Optional extra VectorGrid options (maxNativeZoom, interactive, etc.)
 *
 * The tile URL is built from NEXT_PUBLIC_MARTIN_URL + source name.
 */
const MartinLayer = (layerModel) => {
  const L = getL();
  if (!L) throw new Error('Leaflet must be defined.');

  const VectorGrid = L.vectorGrid;
  if (!VectorGrid) throw new Error('leaflet.vectorgrid must be loaded for Martin layers.');

  const martinUrl = process.env.NEXT_PUBLIC_MARTIN_URL;
  if (!martinUrl) throw new Error('NEXT_PUBLIC_MARTIN_URL is not configured.');

  const { layerConfig, params, sqlParams } = layerModel;
  const layerConfigParsed =
    layerConfig.parse === false
      ? layerConfig
      : JSON.parse(replace(JSON.stringify(layerConfig), params, sqlParams));

  return new Promise((resolve) => {
    const { body } = layerConfigParsed;
    const { source, styles = {}, options = {} } = body;

    const url = `${martinUrl}/${source}/{z}/{x}/{y}`;

    const layer = VectorGrid.protobuf(url, {
      vectorTileLayerStyles: styles,
      ...options,
    });

    resolve(layer);
  });
};

MartinLayer.getBounds = () =>
  new Promise((resolve) => {
    resolve(null);
  });

export default MartinLayer;
