import React from 'react';
import Helmet from 'react-helmet';

import Journey from 'views/components/Journey';

const JourneyPage = () => (
  <>
    <Helmet title="Journeys" />

    <div className="l-content">
      <Journey />
    </div>
  </>
);

export default JourneyPage;
