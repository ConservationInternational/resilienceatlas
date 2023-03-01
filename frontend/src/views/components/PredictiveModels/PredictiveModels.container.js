import { connect } from 'react-redux';
import {
  load as loadModels,
  select,
  applyIndicators,
  resetIndicators,
  makeAll as makeAllModels,
  makeActive as makeActiveModel,
} from '@modules/predictive_models';

import PredictiveModels from './PredictiveModels.component';

const makeMapStateToProps = () => {
  const getAllModels = makeAllModels();
  const getActiveModel = makeActiveModel();

  const mapStateToProps = state => ({
    models: getAllModels(state),
    model: getActiveModel(state),
    indicatorsState: state.predictive_models.indicators_state,
    selectedModel: state.predictive_models.selected,
    modelsLoading: state.predictive_models.loading,
    modelsLoaded: state.predictive_models.loaded,
  });

  return mapStateToProps;
};

const mapDispatchToProps = {
  loadModels,
  select,
  applyIndicators,
  resetIndicators,
};

export default connect(
  makeMapStateToProps,
  mapDispatchToProps,
)(PredictiveModels);
