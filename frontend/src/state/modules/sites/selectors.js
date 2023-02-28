import { createSelector } from 'reselect';
import { denormalize } from 'normalizr';
import { site_scope } from '../../schema';

export const getById = state => state.sites.byId;

export const getAll = state => state.sites.all;

export const makeAllSites = () =>
  createSelector([getAll, getById], (all, site_scopes) =>
    denormalize(all, [site_scope], { site_scopes }),
  );
