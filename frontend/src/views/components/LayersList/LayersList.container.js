import { connect } from 'react-redux';

import { getGrouped } from '@modules/layers';
import LayerList from './LayersList.component';

const mapStateToProps = state => {
  const groupedLayers = getGrouped();

  return {
    groups: state.layers.loaded && state.layer_groups.loaded ? groupedLayers(state) : [],
    loaded: state.layers.loaded && state.layer_groups.loaded,
    loading: state.layers.loading || state.layer_groups.loading,
  };
};

export default connect(mapStateToProps)(LayerList);
