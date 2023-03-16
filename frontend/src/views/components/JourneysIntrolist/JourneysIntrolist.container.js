import { connect } from 'react-redux';
import { load as loadJourneys, makeAll as makeAllJourneys } from 'state/modules/journeys';

// Remove this json when the API is ready
import journeys from '../../../../public/static-journeys/journeys-page-index.json';

const JOURNEYS_API_READY = process.env.NEXT_PUBLIC_FEATURE_JOURNEYS_API === 'true';

const staticJourneys = !JOURNEYS_API_READY && journeys;

import JourneysIntrolist from './JourneysIntrolist.component';

const makeMapStateToProps = () => {
  const getAllJourneys = makeAllJourneys();
  const mapStateToProps = (state) => ({
    journeys: staticJourneys || getAllJourneys(state),
    journeysLoaded: !!staticJourneys || state.journeys.loaded,
  });

  return mapStateToProps;
};

const mapDispatchToProps = {
  loadJourneys,
};

export default connect(makeMapStateToProps, mapDispatchToProps)(JourneysIntrolist);
