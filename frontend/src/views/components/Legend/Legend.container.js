import { compose } from 'redux';
import { connect } from 'react-redux';
import { withRouter } from 'next/router';
import { makeActives, reorder, toggle as toggleLayer, setOpacity } from 'state/modules/layers';
import { makeLayer as makePredictiveModelLayer } from 'state/modules/predictive_models';

import { TABS } from '../Sidebar';

import Legend from './Legend.component';

const makeMapStateToProps = () => {
  const getPredictiveModelLayer = makePredictiveModelLayer();
  const getActives = (state, defaultEmbedURLLayerParams) =>
    makeActives(defaultEmbedURLLayerParams)(state);

  const mapStateToProps = (state, { router, defaultEmbedURLLayerParams }) => {
    const { tab } = router.query;

    if (tab === TABS.MODELS) {
      return {
        activeLayers: [getPredictiveModelLayer(state)].filter(Boolean),
        loading: state.predictive_models.loading,
      };
    }

    return {
      activeLayers: getActives(state, defaultEmbedURLLayerParams),
      loading: state.layers.actives.length > 0 && state.layers.loading,
    };
  };
  return mapStateToProps;
};

const mapDispatchToProps = {
  reorder,
  toggleLayer,
  setOpacity,
};

const withConnect = connect(makeMapStateToProps, mapDispatchToProps);

export default compose(withRouter, withConnect)(Legend);
