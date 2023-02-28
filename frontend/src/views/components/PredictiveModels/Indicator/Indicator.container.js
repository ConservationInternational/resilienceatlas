import { bindActionCreators } from 'redux';
import { connect } from 'react-redux';
import { toggleIndicator, updateIndicator } from '@modules/predictive_models';

import Indicator from './Indicator.component';

const mapStateToProps = (state, { index }) => ({
  stateValue: state.predictive_models.indicators_state[index],
});

const mapDispatchToProps = (dispatch, { index }) =>
  bindActionCreators(
    {
      toggleIndicator,
      updateIndicator: value => updateIndicator(index, value),
    },
    dispatch,
  );

export default connect(mapStateToProps, mapDispatchToProps)(Indicator);
