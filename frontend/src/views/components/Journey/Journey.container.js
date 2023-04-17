import { withRouter } from 'next/router';
import { compose } from 'redux';
import { connect } from 'react-redux';

import {
  load as loadJourneys,
  loadOne as loadJourney,
  getById,
  getJourneysLength,
} from 'state/modules/journeys';
import Journey from './Journey.component';

const mapStateToProps = (state, { router }) => {
  const { query } = router;

  return {
    journeysById: getById(state),
    journeysLoaded: state.journeys.loaded,
    journeysLength: getJourneysLength(state),
    journeyLoaded: state.journey.loaded === query.id,
    journey: state.journey.data,
    translations: state.translations.data,
    query,
  };
};

const mapDispatchToProps = {
  loadJourneys,
  loadJourney,
};

const withConnect = connect(mapStateToProps, mapDispatchToProps);

export default compose(withRouter, withConnect)(Journey);
