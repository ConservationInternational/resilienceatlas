export const SET_DRAWING = 'map / SET_DRAWING';
export const SET_GEOJSON = 'map / SET_GEOJSON';
export const SET_BASEMAP = 'map / SET_BASEMAP';
export const SET_LABELS = 'map / SET_LABELS';
export const SET_BOUNDS = 'map / SET_BOUNDS';
export const SET_ISO = 'map / SET_ISO';
export const SET_MAP_LAYER_GROUPS_INTERACTION = 'map / SET_LAYER_GROUPS_INTERACTION';
export const SET_MAP_LAYER_GROUPS_INTERACTION_LATLNG = 'map / SET_LAYER_GROUPS_INTERACTION_LATLNG';
export const SET_MAP_LAYER_GROUPS_INTERACTION_SELECTED =
  'map / SET_LAYER_GROUPS_INTERACTION_SELECTED';

export const setDrawing = (payload) => ({
  type: SET_DRAWING,
  payload,
});

export const setGeojson = (payload) => ({
  type: SET_GEOJSON,
  payload,
});

export const setBasemap = (payload) => ({
  type: SET_BASEMAP,
  payload,
});

export const setLabels = (payload) => ({
  type: SET_LABELS,
  payload,
});

export const setBounds = (payload) => ({
  type: SET_BOUNDS,
  payload,
});

export const setISO = (payload) => ({
  type: SET_ISO,
  payload,
});

export const fitBounds = (bounds) => (dispatch) => {
  dispatch(setBounds(bounds));

  setTimeout(() => {
    dispatch(setBounds(null));
  }, 200);
};

export const setMapLayerGroupsInteraction = (layer) => ({
  type: SET_MAP_LAYER_GROUPS_INTERACTION,
  layer,
});

export const setMapLayerGroupsInteractionLatLng = (layerGroupsInteractionLatLng) => ({
  type: SET_MAP_LAYER_GROUPS_INTERACTION_LATLNG,
  layerGroupsInteractionLatLng,
});

export const setMapLayerGroupsInteractionSelected = (layerGroupsInteractionSelected) => ({
  type: SET_MAP_LAYER_GROUPS_INTERACTION_SELECTED,
  layerGroupsInteractionSelected,
});
