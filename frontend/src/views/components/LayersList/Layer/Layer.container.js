import { compose } from 'redux';
import { connect } from 'react-redux';
import { withRouter } from 'next/router';

import { toggle, setOpacity, getLayerActive } from 'state/modules/layers';

import Layer from './Layer.component';

const mapStateToProps = (state, { id }) => {
  const isActive = getLayerActive(id);

  return {
    isActive: isActive(state),
    user: state.user,
  };
};

const mapDispatchToProps = {
  toggle,
  setOpacity,
};

export default compose(withRouter, connect(mapStateToProps, mapDispatchToProps))(Layer);
