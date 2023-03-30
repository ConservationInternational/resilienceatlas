import { connect } from 'react-redux';
import { makeActive } from 'state/modules/predictive_models';

import { PredictiveModelAnalysis } from './PredictiveModelAnalysis.component';

const makeMapStateToProps = () => {
  const getActiveModel = makeActive();

  const mapStateToProps = (state) => ({
    model: getActiveModel(state),
    selectedModel: state.predictive_models.selected,
    loaded: state.predictive_models.loaded,
    geojson: state.map.geojson,
  });

  return mapStateToProps;
};

export default connect(makeMapStateToProps)(PredictiveModelAnalysis);
