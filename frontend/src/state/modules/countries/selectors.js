import { createSelector } from 'reselect';
import { denormalize } from 'normalizr';
import { country } from '../../schema';

export const getAll = state => state.countries.all;

export const getByISO = state => state.countries.byISO;

export const makeCountries = () =>
  createSelector([getAll, getByISO], (all, countries) =>
    denormalize(all, [country], { countries }),
  );
