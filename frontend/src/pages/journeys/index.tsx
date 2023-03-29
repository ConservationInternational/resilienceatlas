import JourneysIntrolist from 'views/components/JourneysIntrolist';
import MainLayout from 'views/layouts/main';
import { T } from '@transifex/react';

import type { NextPageWithLayout } from '../_app';

const JourneysPage: NextPageWithLayout = () => (
  <div className="l-content">
    <div className="l-journey__index" id="journeyIndexView">
      <div className="m-journey__title">
        <h1>
          <T _str="Discover Journeys" />
        </h1>
      </div>

      <JourneysIntrolist />
    </div>
  </div>
);

JourneysPage.Layout = (page) => <MainLayout pageTitle="Journeys">{page}</MainLayout>;

export default JourneysPage;
