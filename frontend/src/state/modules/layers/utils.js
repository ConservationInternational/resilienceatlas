import { normalize } from 'normalizr';
import { replace } from 'resilience-layer-manager';

import { getRouterParam } from 'utilities';

import { persisted_layer } from '../../schema';

export const URL_PERSISTED_KEYS = ['date', 'opacity', 'order', 'chartLimit'];

export const getPersistedLayers = () => {
  const persistedLayers = getRouterParam('layers', JSON.parse);

  return normalize(persistedLayers || {}, [persisted_layer]);
};

export const getActiveFromDefaults = (defaults) => (g) =>
  typeof g.active === 'undefined' ? defaults.some((id) => id === g.id) : g.active;

export const parseDates = (layer) => {
  const { timeline, date } = layer;
  if (!timeline) return layer;

  const getDateParams = (timeline, date) => {
    const selectedDate = !!date ? new Date(date) : timeline.defaultDate;
    return {
      day: selectedDate.getDate(),
      month: String(selectedDate.getMonth() + 1).padStart(2, '0'), // Months need to have 2 digits
      year: selectedDate.getFullYear(),
    };
  };
  const replaceDates = (str) => replace(str, getDateParams(timeline, date));
  const { layerConfig } = layer;
  return {
    ...layer,
    analysisBody: layer.analysisBody && replaceDates(layer.analysisBody),
    interactionConfig: layer.interactionConfig && replaceDates(layer.interactionConfig),
    cartocss: layer.cartocss && replaceDates(layer.cartocss),
    sql: layer.sql && replaceDates(layer.cartocss),
    layerConfig: {
      ...layerConfig,
      body: {
        ...layerConfig.body,
        url: layerConfig?.body?.url && replaceDates(layerConfig.body.url),
        layers:
          layer.type === 'cartodb' &&
          layerConfig?.body?.layers?.map((l) => ({
            ...l,
            // Carto Layers
            options: l.options && {
              ...l.options,
              cartocss: l.options.cartocss && replaceDates(l.options.cartocss),
              sql: l.options.sql && replaceDates(l.options.sql),
            },
          })),
      },
    },
  };
};
