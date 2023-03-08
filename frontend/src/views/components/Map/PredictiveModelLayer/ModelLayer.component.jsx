import React from 'react';
import CartoDBLayer from './CartoDBLayer';

const cartodb = window.cartodb || {};

const PredictiveModelLayer = ({ map, predictiveModelLayer: layerObj }) => {
  if (layerObj.type === 'cartodb' || layerObj.type === 'raster') {
    const { sql, cartocss, interactivity } = layerObj;
    const data = { sql, cartocss, interactivity };
    let options = { sublayers: [data] };

    if (layerObj.type === 'raster') {
      options = {
        sublayers: [{ ...data, raster: true, raster_band: 1 }],
      };
    }

    return (
      <CartoDBLayer
        map={map}
        layer={layerObj}
        onCreate={(layer) => {
          layer.setOpacity(layerObj.opacity);
          layer.setZIndex(1000 + layerObj.order);
          // this._setAttribution(layerObj);

          const sublayer = layer.getSubLayer(0);
          // add infowindow interactivity to the sublayer (show cartodb_id and name columns from the table)
          if (options.sublayers.length && layer.layers[0].options.interactivity) {
            cartodb.vis.Vis.addInfowindow(map, sublayer, layer.layers[0].options.interactivity);
          }
        }}
      />
    );
  }
  return null;
};

export default PredictiveModelLayer;
