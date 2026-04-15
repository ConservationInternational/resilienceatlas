import { createSelector } from 'reselect';

const getSlice = (state) => state.scope_datasets;

export const getDatasets = createSelector(getSlice, (s) => s.datasets);
export const getBySlug = createSelector(getSlice, (s) => s.bySlug);
export const getLoading = createSelector(getSlice, (s) => s.loading);
export const getLoaded = createSelector(getSlice, (s) => s.loaded);
export const getHighlight = createSelector(getSlice, (s) => s.highlight);
export const getHighlightBounds = createSelector(getSlice, (s) => s.highlightBounds);
export const getDetailLoading = createSelector(getSlice, (s) => s.detailLoading);
export const getActiveVariant = createSelector(getSlice, (s) => s.activeVariant);
export const getActiveDimension = createSelector(getSlice, (s) => s.activeDimension);
export const getSpatialFilter = createSelector(getSlice, (s) => s.spatialFilter);

export const getDatasetBySlug = (state, slug) => state.scope_datasets.bySlug[slug] || null;

/**
 * Filter dataset data rows by spatial filter.
 * When a spatial filter is active, only rows whose unit_id (determined by
 * the dataset's dimension_config.unitIdColumn) is in the matching set are kept.
 */
export const getFilteredData = (dataset, spatialFilter) => {
  if (!dataset || !dataset.data) return [];
  if (!spatialFilter) return dataset.data;

  const matchingUnits = spatialFilter[dataset.slug];
  if (!matchingUnits) return dataset.data;

  const unitIdCol = dataset.dimension_config?.unitIdColumn;
  if (!unitIdCol) return dataset.data;

  const unitSet = new Set(matchingUnits.map(String));
  return dataset.data.filter((row) => unitSet.has(String(row[unitIdCol])));
};
