import { createSelector } from 'reselect';
import { denormalize } from 'normalizr';
import { getNestedChildren } from '@utilities/helpers';

import { map_menu_entry } from '../../schema';

export const getById = state => state.map_menu_entries.byId;

export const getAll = state => state.map_menu_entries.all;

export const makeAllEntries = () =>
  createSelector([getAll, getById], (all, map_menu_entries) =>
    denormalize(all, [map_menu_entry], { map_menu_entries }),
  );

export const makeMenuTree = () => {
  const getAllEntries = makeAllEntries();

  return createSelector([getAllEntries], entries => getNestedChildren(entries));
};
