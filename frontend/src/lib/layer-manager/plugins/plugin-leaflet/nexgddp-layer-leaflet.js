import { replace } from '../../utils/query';
import CanvasLayer from './canvas-layer-leaflet';

const { L } = typeof window !== 'undefined' ? window : {};

const NEXGDDPLayer = (layerModel) => {
  if (!L) throw new Error('Leaflet must be defined.');

  const { layerConfig, params, sqlParams, decodeParams, decodeFunction } = layerModel;
  const layerConfigParsed =
    layerConfig.parse === false
      ? layerConfig
      : JSON.parse(replace(JSON.stringify(layerConfig), params, sqlParams));

  return new Promise((resolve) => {
    const { body } = layerConfigParsed;

    const tileLayer = new CanvasLayer({
      params: body,
      sqlParams,
      decodeParams,
      decodeFunction,
    });

    resolve(tileLayer);
  });
};

NEXGDDPLayer.getBounds = () =>
  new Promise((resolve) => {
    resolve(null);
  });

export default NEXGDDPLayer;
