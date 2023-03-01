import React from 'react';
import Helmet from 'react-helmet';

import JourneysIntrolist from '@components/JourneysIntrolist';

const Journeys = () => (
  <>
    <Helmet title="Journeys" />

    <div className="l-content">
      <div className="l-journey__index" id="journeyIndexView">
        <div className="m-journey__title">
          <h1>Discover Journeys</h1>
        </div>

        <JourneysIntrolist />
      </div>
    </div>
  </>
);

export default Journeys;
