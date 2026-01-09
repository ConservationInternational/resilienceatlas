import { replace } from '../../utils/query';
import { getCanvasLayer } from './canvas-layer-leaflet';

// Get L dynamically at runtime, not at module load time
const getL = () => (typeof window !== 'undefined' ? window.L : undefined);

const GEELayer = (layerModel) => {
  const L = getL();
  if (!L) throw new Error('Leaflet must be defined.');

  const { layerConfig, params, sqlParams, decodeParams, decodeFunction } = layerModel;
  const layerConfigParsed =
    layerConfig.parse === false
      ? layerConfig
      : JSON.parse(replace(JSON.stringify(layerConfig), params, sqlParams));

  return new Promise((resolve) => {
    const { body } = layerConfigParsed;

    const CanvasLayer = getCanvasLayer();
    if (!CanvasLayer) throw new Error('CanvasLayer could not be created - Leaflet not available');

    const tileLayer = new CanvasLayer({
      params: body,
      sqlParams,
      decodeParams,
      decodeFunction,
    });

    resolve(tileLayer);
  });
};

GEELayer.getBounds = () =>
  new Promise((resolve) => {
    resolve(null);
  });

export default GEELayer;
