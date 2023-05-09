import { createSelector } from 'reselect';
import { denormalize } from 'normalizr';

import { sortBy } from 'utilities/helpers';

import {
  getById as getGroupsById,
  getGroups,
  getCategories,
  getSubCategories,
  getSubGroups,
} from '../layer_groups';
import { layer } from '../../schema';
import { getActiveFromDefaults } from './utils';

const byDashboardOrder = sortBy('dashboard_order');
const getOpacityText = (v) => parseInt(v * 100, 10);

export const getLoaded = (state) => state.layers.loaded;

export const getById = (state) => state.layers.byId;

const getSourcesById = (state) => state.sources.byId;

export const getAllIds = (state) => state.layers.all;

export const getActiveIds = (state) => state.layers.actives;

export const getPublished = createSelector([getAllIds, getById], (all, layers) =>
  denormalize(all, [layer], { layers }).filter((i) => i.published),
);

const getInfo = (sourcesById, layer) => {
  const { description, sourceIds } = layer;
  let info = { description };
  if (!sourceIds || !sourceIds[0]) return info;

  const id = sourceIds[0];
  if (!sourcesById[id]) return info;
  const { reference_short, url } = sourcesById[id];
  return {
    ...info,
    source: reference_short,
    link: url,
  };
};

export const makeActives = () =>
  createSelector(
    [getActiveIds, getById, getLoaded, getSourcesById],
    (ids, layers, loaded, sourcesById) => {
      if (!loaded) return [];
      const activeLayers = denormalize(ids, [layer], { layers });
      return activeLayers
        .filter((activeLayers) => !!activeLayers)
        .map((layer) => ({
          ...layer,
          info: getInfo(sourcesById, layer),
        }));
    },
  );

export const makeDefaultActives = () => {
  const getActives = makeActives();

  return createSelector([getActives, getGroupsById], (activeLayers, byId) => {
    const result = new Set();
    const collectIds = (id, entities) => {
      result.add(id);

      const { father } = entities[id] || {};
      if (father) collectIds(father, entities);
    };

    if (activeLayers.length > 0) {
      activeLayers.map((l) => collectIds(l.group, byId));
    }

    return [...result];
  });
};

export const getGrouped = () => {
  const getDefaultActives = makeDefaultActives();

  return createSelector(
    [
      getPublished,
      getGroups,
      getCategories,
      getSubCategories,
      getSubGroups,
      getDefaultActives,
      getSourcesById,
    ],
    (
      published,
      groups,
      g_categories,
      g_subcategories,
      g_subgroups,
      g_defaultActive,
      sourcesById,
    ) => {
      const isActive = getActiveFromDefaults(g_defaultActive);
      if (!groups.length && !g_categories.length) {
        // eslint-disable-next-line no-console
        console.info('There aren`t groups setted.');
        return groups;
      }
      return groups.sort(sortBy('order')).map((g) => {
        const groupLayers = published.filter((l) => l.group === g.id);

        const categories = g_categories.filter((c) => c.father === g.id);

        const getLayerProps = (layer) => ({
          opacity_text: getOpacityText(layer.opacity),
          info: getInfo(sourcesById, layer),
        });

        return {
          ...g,
          active: isActive(g),
          layers: groupLayers.map((l) => ({
            ...l,
            ...getLayerProps(l),
          })),
          categories: categories.map((c) => {
            const layers = published.filter((l) => l.group === c.id);

            const subcategories = g_subcategories.filter((s) => s.father === c.id);
            return {
              ...c,
              active: isActive(c),
              layers: layers.map((l) => ({
                ...l,
                ...getLayerProps(l),
              })),
              subcategory: subcategories.map((sc) => {
                const layers = published.filter((l) => l.group === sc.id);

                const subgroups = g_subgroups.filter((sg) => sg.father === sc.id);

                return {
                  ...sc,
                  active: isActive(sc),
                  layers: layers.sort(byDashboardOrder).map((l) => ({
                    ...l,
                    ...getLayerProps(l),
                  })),
                  subgroup: subgroups.map((sg) => ({
                    ...sg,
                    layers: published
                      .filter((layer) => layer.group === sg.id)
                      .map((l) => ({
                        ...l,
                        ...getLayerProps(l),
                      })),
                  })),
                };
              }),
            };
          }),
        };
      });
    },
  );
};

export const getLayerActive = (id) => createSelector(getActiveIds, (ids) => new Set(ids).has(id));

export const getInteractionLayers = () => {
  const getActive = makeActives();

  return createSelector([getActive], (layers) =>
    layers
      .filter((l) => l.interactionConfig && l.interactionConfig.length)
      .map((l) => ({
        ...l,
        interactionConfig: JSON.parse(l.interactionConfig),
      })),
  );
};
