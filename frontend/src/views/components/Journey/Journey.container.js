import { withRouter } from 'next/router';
import { compose } from 'redux';
import { connect } from 'react-redux';

import journey1 from '../../../../public/static-journeys/1.json';
import journey2 from '../../../../public/static-journeys/2.json';
import journey3 from '../../../../public/static-journeys/3.json';
import journey4 from '../../../../public/static-journeys/4.json';
import journey5 from '../../../../public/static-journeys/5.json';

import {
  load as loadJourneys,
  loadOne as loadJourney,
  getJourneysLength,
} from 'state/modules/journeys';
import Journey from './Journey.component';

const JOURNEYS_API_READY = process.env.NEXT_PUBLIC_FEATURE_JOURNEYS_API === 'true';
const staticJourneys =
  !JOURNEYS_API_READY && [journey1, journey2, journey3, journey4, journey4, journey5].flat();

const mapStateToProps = (state, { router }) => {
  const { query } = router;

  return {
    journeysLength: !!staticJourneys && query.id ? staticJourneys.length : getJourneysLength(state),
    journeyLoaded: (!!staticJourneys && query.id) || state.journey.loaded === query.id,
    journey: (query.id && !!staticJourneys && staticJourneys[query.id - 1]) || state.journey.data,
    query,
  };
};

const mapDispatchToProps = {
  loadJourneys,
  loadJourney,
};

const withConnect = connect(mapStateToProps, mapDispatchToProps);

export default compose(withRouter, withConnect)(Journey);
