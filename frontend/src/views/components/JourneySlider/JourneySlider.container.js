import { connect } from 'react-redux';
import { load as loadJourneys, makeAll as makeAllJourneys } from 'state/modules/journeys';

import JourneySlider from './JourneySlider.component';

const makeMapStateToProps = () => {
  const getAllJourneys = makeAllJourneys();

  const mapStateToProps = (state) => ({
    journeys: getAllJourneys(state),
    journeysLoaded: state.journeys.loaded,
    journeysLoadedLocale: state.journeys.loadedLocale,
  });

  return mapStateToProps;
};

const mapDispatchToProps = {
  loadJourneys,
};

export default connect(makeMapStateToProps, mapDispatchToProps)(JourneySlider);
