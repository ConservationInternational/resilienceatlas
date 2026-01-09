import { fetchCluster } from '../../services/cluster-service';

const { L, $: jQuery } = typeof window !== 'undefined' ? window : {};

const ClusterLayer = (layerModel) => {
  if (!L) throw new Error('Leaflet must be defined.');

  const {
    map,
    layerConfig: { body },
  } = layerModel;
  const { sql, cartocss, interactivity } = body;

  return new Promise((resolve, reject) => {
    fetchCluster({ sql, cartocss, interactivity })
      .then((response) => {
        const config = response;

        const sublayers = config.layers;
        const visibility = sublayers.map(() => true);

        const addCursor = (layer) => {
          jQuery(layer.getContainer()).css('cursor', 'pointer');
        };

        const removeCursor = (layer) => {
          jQuery(layer.getContainer()).css('cursor', 'default');
        };

        const sublayerOptions = {
          sql,
          cartocss,
          interactivity,
        };

        const layer = L.tileLayer.canvas({
          user: 'ra',
          sql: sublayerOptions.sql,
          cartocss: sublayerOptions.cartocss,
          interactivity: sublayerOptions.interactivity,
        });

        layer.addTo(map);

        const queryData = (latlng, data, callback) => {
          const { cartodb_id: cartodbId } = data;
          callback({
            position: latlng,
            column: cartodbId,
          });
        };

        layer.on('loading', () => {
          addCursor(layer);
        });

        layer.on('load', () => {
          removeCursor(layer);
        });

        layer.on('click', (evt) => {
          const { data, latlng } = evt;
          queryData(latlng, data, (info) => {
            const { position, column } = info;
            layerModel.events.click({ position, data: column, evt });
          });
        });

        return resolve(layer);
      })
      .catch((err) => reject(err));
  });
};

export default ClusterLayer;
