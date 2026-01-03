import React from 'react';
import legends from './legends';

const LegendItem = ({ legend: legendStr, layer }) => {
  if (legendStr) {
    // Try to parse the legend JSON, handle invalid JSON gracefully
    let legend;
    try {
      legend = JSON.parse(legendStr);
    } catch (e) {
      // If the legend string is not valid JSON, skip rendering
      console.warn(`Invalid legend JSON for layer ${layer?.id}:`, e.message);
      return null;
    }

    const { type } = legend;
    let options = {};

    // Ensure the legend type exists in our legends registry
    if (!type || !legends[type]) {
      console.warn(`Unknown legend type "${type}" for layer ${layer?.id}`);
      return null;
    }

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
