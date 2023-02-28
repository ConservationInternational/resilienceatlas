import { compose } from 'redux';
import { connect } from 'react-redux';
import { withRouter } from 'react-router-dom';

import { toggle, setOpacity, getLayerActive } from '@modules/layers';

import Layer from './Layer.component';

const mapStateToProps = (state, { id, LayerGroupName }) => {
  const isActive = getLayerActive(id);

  return {
    isActive: isActive(state),
    user: state.user,
    LayerGroupName: LayerGroupName,
  };
};

const mapDispatchToProps = {
  toggle,
  setOpacity,
};

export default compose(
  withRouter,
  connect(mapStateToProps, mapDispatchToProps),
)(Layer);
