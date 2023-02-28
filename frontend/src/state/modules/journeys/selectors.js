import { createSelector } from 'reselect';
import { denormalize } from 'normalizr';
import { journey } from '../../schema';

export const getAll = state => state.journeys.all;

export const getById = state => state.journeys.byId;

export const getJourneysLength = state => state.journeys.all.length;

export const makeAll = () =>
  createSelector([getAll, getById], (all, journeys) =>
    denormalize(all, [journey], { journeys }),
  );

export const makeOne = () =>
  createSelector([(s, id) => id, getById], (journeys, id) =>
    denormalize(id, journey, { journeys }),
  );
