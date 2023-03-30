import MainLayout from 'views/layouts/main';

import type { NextPageWithLayout } from './_app';

const ShinnyAppPage: NextPageWithLayout = () => (
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
);

ShinnyAppPage.Layout = (page) => <MainLayout pageTitle="Shinny App">{page}</MainLayout>;

export default ShinnyAppPage;
