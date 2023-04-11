import { connect } from 'react-redux';
import { load as loadJourneys, makeAll as makeAllJourneys } from 'state/modules/journeys';

import Journeys from './Journeys.component';

const makeMapStateToProps = () => {
  const getAllJourneys = makeAllJourneys();

  const mapStateToProps = (state) => ({
    journeys: getAllJourneys(state),
    journeysLoaded: state.journeys.loaded,
  });

  return mapStateToProps;
};

const mapDispatchToProps = {
  loadJourneys,
};

export default connect(makeMapStateToProps, mapDispatchToProps)(Journeys);
