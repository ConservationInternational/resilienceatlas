import qs from 'qs';
import { compose } from 'redux';
import { connect } from 'react-redux';
import { withRouter } from 'react-router-dom';
import {
  makeActives,
  reorder,
  toggle as toggleLayer,
  setOpacity,
} from '@modules/layers';
import { makeLayer as makePredictiveModelLayer } from '@modules/predictive_models';

import { TABS } from '../Sidebar';

import Legend from './Legend.component';

const makeMapStateToProps = () => {
  const getPredictiveModelLayer = makePredictiveModelLayer();
  const getActives = makeActives();

  const mapStateToProps = (state, { location }) => {
    const { tab } = qs.parse(location.search, { ignoreQueryPrefix: true });

    if (tab === TABS.MODELS) {
      return {
        activeLayers: [getPredictiveModelLayer(state)].filter(Boolean),
        loading: state.predictive_models.loading,
      };
    }

    return {
      activeLayers: getActives(state),
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
