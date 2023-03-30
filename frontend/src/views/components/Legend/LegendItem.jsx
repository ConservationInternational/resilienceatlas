import React from 'react';
import legends from './legends';

const LegendItem = ({ legend: legendStr, layer }) => {
  if (legendStr) {
    const legend = JSON.parse(legendStr);
    const { type } = legend;
    let options = {};

    if (type === 'chart') {
      options = {
        ...options,
        layerId: layer.id,
        limit: layer.chartLimit,
      };
    }

    return React.createElement(legends[type], { ...legend, ...options });
  }
  return null;
};

export default LegendItem;
