import { connect } from 'react-redux';

import { getInteractionLayers } from 'state/modules/layers';

import { setMapLayerGroupsInteractionSelected } from 'state/modules/map';

import MapPopup from './MapPopup.component';

const makeMapStateToProps = () => {
  const interactionlayers = getInteractionLayers();

  const mapStateToProps = (state) => ({
    layersInteraction: interactionlayers(state),
    layerGroupsInteraction: state.map.layerGroupsInteraction,
    layerGroupsInteractionSelected: state.map.layerGroupsInteractionSelected,
    layerGroupsInteractionLatLng: state.map.layerGroupsInteractionLatLng,
  });
  return mapStateToProps;
};

const mapDispatchToProps = {
  setMapLayerGroupsInteractionSelected,
};

export default connect(makeMapStateToProps, mapDispatchToProps)(MapPopup);
