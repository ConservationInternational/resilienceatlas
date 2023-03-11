import Head from 'next/head';

import JourneysIntrolist from 'views/components/JourneysIntrolist';
import MainLayout from 'views/layouts/main';

import type { NextPageWithLayout } from '../_app';

const JourneysPage: NextPageWithLayout = () => (
  <>
    <Head>
      <title>Journeys</title>
    </Head>
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

JourneysPage.Layout = (page) => <MainLayout>{page}</MainLayout>;

export default JourneysPage;
