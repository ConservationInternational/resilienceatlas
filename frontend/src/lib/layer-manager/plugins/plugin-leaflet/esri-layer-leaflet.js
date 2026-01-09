import { replace } from '../../utils/query';

const { L } = typeof window !== 'undefined' ? window : {};

const EsriLayer = (layerModel) => {
  if (!L || !L.esri) throw new Error('Leaflet and esri-leaflet must be defined.');

  const { layerConfig, params, sqlParams } = layerModel;
  const layerConfigParsed =
    layerConfig.parse === false
      ? layerConfig
      : JSON.parse(replace(JSON.stringify(layerConfig), params, sqlParams));

  return new Promise((resolve) => {
    const { body } = layerConfigParsed;
    const { url, type = 'dynamicMapLayer', options = {} } = body;

    const layer = L.esri[type]({ url, ...options });

    resolve(layer);
  });
};

EsriLayer.getBounds = (layerModel) => {
  if (!L || !L.esri) throw new Error('Leaflet and esri-leaflet must be defined.');

  const { layerConfig, params, sqlParams } = layerModel;
  const layerConfigParsed =
    layerConfig.parse === false
      ? layerConfig
      : JSON.parse(replace(JSON.stringify(layerConfig), params, sqlParams));

  return new Promise((resolve, reject) => {
    const { body } = layerConfigParsed;
    const { url, type = 'dynamicMapLayer', options = {} } = body;

    const layer = L.esri[type]({ url, ...options });

    layer.metadata((err, data) => {
      if (err) {
        reject(err);
      }

      if (data && data.extent) {
        const { xmin, ymin, xmax, ymax } = data.extent;
        const bounds = [
          [ymax, xmax],
          [ymin, xmin],
        ];

        resolve(bounds);
      }

      resolve(null);
    });
  });
};

export default EsriLayer;
