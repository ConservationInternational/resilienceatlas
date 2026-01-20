import { createSelector } from 'reselect';
import { getById as getLayersById } from '../layers';

// Base selectors
export const getCompareState = (state) => state.compare;
export const getCompareEnabled = (state) => state.compare?.enabled || false;
export const getLeftLayerId = (state) => state.compare?.leftLayerId || null;
export const getRightLayerId = (state) => state.compare?.rightLayerId || null;
export const getSliderPosition = (state) => state.compare?.sliderPosition || 50;

/**
 * Factory to create a layer selector by side to avoid duplication
 * @param {Function} getLayerIdSelector - Selector for the layer ID
 * @returns {Function} Memoized selector returning the full layer object
 */
const makeGetLayerBySide = (getLayerIdSelector) =>
  createSelector([getLayerIdSelector, getLayersById], (layerId, layersById) => {
    if (!layerId || !layersById) return null;
    return layersById[layerId] || null;
  });

/**
 * Get the full left layer object
 */
export const getLeftLayer = makeGetLayerBySide(getLeftLayerId);

/**
 * Get the full right layer object
 */
export const getRightLayer = makeGetLayerBySide(getRightLayerId);

/**
 * Check if a specific layer is selected for comparison
 * @param {number|string} layerId - The layer ID to check
 * @returns {'left'|'right'|null} - Which side the layer is on, or null if not in compare
 */
export const makeGetLayerCompareStatus = () =>
  createSelector(
    [getLeftLayerId, getRightLayerId, (_, layerId) => layerId],
    (leftLayerId, rightLayerId, layerId) => {
      if (leftLayerId === layerId) return 'left';
      if (rightLayerId === layerId) return 'right';
      return null;
    },
  );

/**
 * Check if compare mode is ready (both layers selected)
 */
export const getCompareReady = createSelector(
  [getCompareEnabled, getLeftLayerId, getRightLayerId],
  (enabled, leftLayerId, rightLayerId) => Boolean(enabled && leftLayerId && rightLayerId),
);

/**
 * Get compare state for URL serialization
 * Returns null if compare is not enabled or not ready
 */
export const getCompareURLState = createSelector(
  [getCompareEnabled, getLeftLayerId, getRightLayerId, getSliderPosition],
  (enabled, leftLayerId, rightLayerId, sliderPosition) => {
    if (!enabled || !leftLayerId || !rightLayerId) return null;
    return {
      enabled,
      left: leftLayerId,
      right: rightLayerId,
      pos: sliderPosition,
    };
  },
);
