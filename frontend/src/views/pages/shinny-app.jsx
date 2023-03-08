import React from 'react';
import Helmet from 'react-helmet';

const ShinnyApp = () => (
  <>
    <Helmet title="Shinny App" />

    <div className="l-content">
      <div className="l-journey__index" id="journeyIndexView">
        <div className="m-journey__title">
          <h1>Shinny App</h1>
        </div>

        <div>
          <iframe
            src="https://sparc-apps.shinyapps.io/irrecoverable_carbon_biodiversity_app_internal/"
            width="99%"
            height="1000px"
          />
        </div>
      </div>
    </div>
  </>
);

export default ShinnyApp;
