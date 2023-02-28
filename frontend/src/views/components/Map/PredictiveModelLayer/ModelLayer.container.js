import { connect } from 'react-redux';

import { makeLayer as makePredictiveModelLayer } from '@modules/predictive_models';

import PredictiveModelLayer from './ModelLayer.component';

const makeMapStateToProps = () => {
  const getPredictiveModelLayer = makePredictiveModelLayer();

  const mapStateToProps = state => ({
    predictiveModelLayer: getPredictiveModelLayer(state),
  });

  return mapStateToProps;
};
export default connect(makeMapStateToProps)(PredictiveModelLayer);
