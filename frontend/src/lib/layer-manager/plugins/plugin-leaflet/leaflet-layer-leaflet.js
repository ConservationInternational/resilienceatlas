import { replace } from '../../utils/query';

const { L } = typeof window !== 'undefined' ? window : {};

const LeafletLayer = (layerModel) => {
  if (!L) throw new Error('Leaflet must be defined.');

  const { layerConfig, params, sqlParams } = layerModel;
  const layerConfigParsed =
    layerConfig.parse === false
      ? layerConfig
      : JSON.parse(replace(JSON.stringify(layerConfig), params, sqlParams));

  return new Promise((resolve) => {
    const { body } = layerConfigParsed;
    const { url, type = 'tileLayer', options = {} } = body;

    const layer = L[type](url, options);

    resolve(layer);
  });
};

LeafletLayer.getBounds = () =>
  new Promise((resolve) => {
    resolve(null);
  });

export default LeafletLayer;
