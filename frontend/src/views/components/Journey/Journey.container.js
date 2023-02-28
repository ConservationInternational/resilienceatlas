import { compose } from 'redux';
import { connect } from 'react-redux';
import { withRouter } from 'react-router-dom';

import {
  load as loadJourneys,
  loadOne as loadJourney,
  getJourneysLength,
} from '@modules/journeys';

import Journey from './Journey.component';

const mapStateToProps = (state, { match }) => {
  const {
    params: { id },
  } = match;

  return {
    journeysLength: getJourneysLength(state),
    journeyLoaded: state.journey.loaded === id,
    journey: state.journey.data,
  };
};

const mapDispatchToProps = {
  loadJourneys,
  loadJourney,
};

const withConnect = connect(mapStateToProps, mapDispatchToProps);

export default compose(withRouter, withConnect)(Journey);
