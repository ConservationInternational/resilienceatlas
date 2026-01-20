// Compare mode action constants
export const ENABLE_COMPARE = 'compare/ENABLE';
export const DISABLE_COMPARE = 'compare/DISABLE';
export const SET_LEFT_LAYER = 'compare/SET_LEFT_LAYER';
export const SET_RIGHT_LAYER = 'compare/SET_RIGHT_LAYER';
export const SET_SLIDER_POSITION = 'compare/SET_SLIDER_POSITION';
export const CLEAR_LAYER = 'compare/CLEAR_LAYER';

// Cross-module action type for reordering layers (handled by layers reducer)
export const MOVE_COMPARE_LAYERS_TO_TOP = 'compare/MOVE_COMPARE_LAYERS_TO_TOP';

/**
 * Enable compare mode
 */
export const enableCompare = () => ({
  type: ENABLE_COMPARE,
});

/**
 * Disable compare mode and clear selected layers
 */
export const disableCompare = () => ({
  type: DISABLE_COMPARE,
});

/**
 * Set the left layer for comparison
 * @param {number|string} layerId - The layer ID to set as left layer
 */
export const setLeftLayer = (layerId) => ({
  type: SET_LEFT_LAYER,
  layerId,
});

/**
 * Set the right layer for comparison
 * @param {number|string} layerId - The layer ID to set as right layer
 */
export const setRightLayer = (layerId) => ({
  type: SET_RIGHT_LAYER,
  layerId,
});

/**
 * Set the slider position (0-100)
 * @param {number} position - Slider position percentage
 */
export const setSliderPosition = (position) => ({
  type: SET_SLIDER_POSITION,
  position,
});

/**
 * Clear a specific layer from comparison
 * @param {'left'|'right'} side - Which side to clear
 */
export const clearLayer = (side) => ({
  type: CLEAR_LAYER,
  side,
});

/**
 * Toggle a layer in compare mode - smart assignment logic:
 * - If compare is disabled, enable it and set as left layer
 * - If layer is already selected, remove it from that side
 * - If left is empty, set as left
 * - If right is empty, set as right
 * - If both are set, replace right
 * When both layers are set, automatically moves them to top of legend
 * @param {number|string} layerId - The layer ID to toggle
 */
export const toggleCompareLayer = (layerId) => (dispatch, getState) => {
  const { compare } = getState();
  const { enabled, leftLayerId, rightLayerId } = compare;

  // If compare mode is disabled, enable it and set this as left layer
  if (!enabled) {
    dispatch(enableCompare());
    dispatch(setLeftLayer(layerId));
    return;
  }

  // If this layer is already selected on left, remove it
  if (leftLayerId === layerId) {
    dispatch(setLeftLayer(null));
    return;
  }

  // If this layer is already selected on right, remove it
  if (rightLayerId === layerId) {
    dispatch(setRightLayer(null));
    return;
  }

  // If left is empty, set as left
  if (!leftLayerId) {
    dispatch(setLeftLayer(layerId));
    // Check if right is already set - if so, move both to top
    if (rightLayerId) {
      dispatch(moveCompareLayersToTop(layerId, rightLayerId));
    }
    return;
  }

  // If right is empty, set as right
  if (!rightLayerId) {
    dispatch(setRightLayer(layerId));
    // Left is already set, move both to top
    dispatch(moveCompareLayersToTop(leftLayerId, layerId));
    return;
  }

  // Both are set, replace right layer
  dispatch(setRightLayer(layerId));
  // Move the new pair to top
  dispatch(moveCompareLayersToTop(leftLayerId, layerId));
};

/**
 * Move comparison layers to the top of the legend order.
 * Called when compare mode becomes ready (both layers selected).
 * @param {number|string} leftLayerId - The left layer ID
 * @param {number|string} rightLayerId - The right layer ID
 */
export const moveCompareLayersToTop = (leftLayerId, rightLayerId) => ({
  type: MOVE_COMPARE_LAYERS_TO_TOP,
  leftLayerId,
  rightLayerId,
});

/**
 * Check if a layer being removed is used in comparison and exit compare mode if so.
 * This is a thunk action that checks the compare state before removing.
 * @param {number|string} layerId - The layer ID being removed
 */
export const handleLayerRemoval = (layerId) => (dispatch, getState) => {
  const { compare } = getState();
  const { enabled, leftLayerId, rightLayerId } = compare;

  // If compare mode is enabled and this layer is part of the comparison, disable compare
  // Use String() to ensure consistent comparison regardless of type
  if (
    enabled &&
    (String(leftLayerId) === String(layerId) || String(rightLayerId) === String(layerId))
  ) {
    dispatch(disableCompare());
  }
};
