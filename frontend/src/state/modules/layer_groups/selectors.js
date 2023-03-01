import { createSelector } from 'reselect';
import { denormalize } from 'normalizr';
import { layer_group } from '../../schema';

export const getById = state => state.layer_groups.byId;

export const getAll = state => state.layer_groups.all;

export const getPublished = createSelector(
  [getById, getAll],
  (layer_groups, all) => denormalize(all, [layer_group], { layer_groups }),
  // TODO: add published column to layers groups
  // .filter(lg => lg.published),
);

export const getGroups = createSelector(getPublished, published =>
  published.filter(lg => !lg.father),
);

export const getCategories = createSelector(getPublished, published =>
  published.filter(lg => !!lg.father),
);

export const getSubCategories = createSelector(getPublished, published =>
  published.filter(lg => lg.group_type === 'subcategory'),
);

export const getSubGroups = createSelector(getPublished, published =>
  published.filter(lg => lg.group_type === 'subgroup'),
);

export const getCategoriesByGroup = groupId =>
  createSelector(getPublished, published =>
    published.filter(lg => groupId === lg.father),
  );
