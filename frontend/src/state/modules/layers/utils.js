import { normalize } from 'normalizr';

import { getRouterParam } from 'utilities';

import { persisted_layer } from '../../schema';

export const getPersistedLayers = () => {
  const persistedLayers = getRouterParam('layers', JSON.parse);

  return normalize(persistedLayers || {}, [persisted_layer]);
};

export const getActiveFromDefaults = (defaults) => (g) =>
  typeof g.active === 'undefined' ? defaults.some((id) => id === g.id) : g.active;
