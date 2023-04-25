import { compose } from 'redux';
import { connect } from 'react-redux';
import { withRouter } from 'next/router';
import dynamic from 'next/dynamic';

import {
  load as loadLayers,
  setActives,
  getGrouped,
  makeActives,
  makeDefaultActives,
  setOpacity,
} from 'state/modules/layers';
import { load as loadLayerGroups, openBatch } from 'state/modules/layer_groups';
import { makeLayer as makeModelLayer } from 'state/modules/predictive_models';
import {
  setMapLayerGroupsInteraction,
  setMapLayerGroupsInteractionLatLng,
} from 'state/modules/map';

const MapViewNoSSR = dynamic(() => import('./Map.component'), { ssr: false });

const makeMapStateToProps = () => {
  const groupedLayers = getGrouped();
  const defaultActives = makeDefaultActives();
  const getModelLayer = makeModelLayer();
  const getActives = makeActives();

  const mapStateToProps = (state) => ({
    tab: state.ui.tab,
    site: state.site,
    layers: state.layers,
    drawing: state.map.drawing,
    geojson: state.map.geojson,
    basemap: state.map.basemap,
    labels: state.map.labels,
    layer_groups: state.layer_groups,
    activeLayers: getActives(state),
    model_layer: getModelLayer(state),
    defaultActiveGroups: defaultActives(state),
    grouped: groupedLayers(state),
  });

  return mapStateToProps;
};

const mapDispatchToProps = {
  loadLayers,
  loadLayerGroups,
  setActives,
  openBatch,
  setMapLayerGroupsInteraction,
  setMapLayerGroupsInteractionLatLng,
  setOpacity,
};

export default compose(withRouter, connect(makeMapStateToProps, mapDispatchToProps))(MapViewNoSSR);
