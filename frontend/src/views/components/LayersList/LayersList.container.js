import { connect } from 'react-redux';

import { getGrouped } from 'state/modules/layers';
import LayerList from './LayersList.component';

const mapStateToProps = (state) => {
  const groupedLayers = getGrouped();

  const layersLoaded = state.layers.loaded;
  const layerGroupsLoaded = state.layer_groups.loaded;
  const groups = layersLoaded && layerGroupsLoaded ? groupedLayers(state) : [];

  return {
    groups,
    loaded: layersLoaded && layerGroupsLoaded,
    loading: state.layers.loading || state.layer_groups.loading,
  };
};

export default connect(mapStateToProps)(LayerList);
