import Head from 'next/head';

import Journey from 'views/components/Journey';
import FullscreenLayout from 'views/layouts/fullscreen';

import type { NextPageWithLayout } from '../../../_app';

const JourneyDetailPage: NextPageWithLayout = () => (
  <>
    <Head>
      <title>Journeys</title>
    </Head>
    <div className="l-content">
      <Journey />
    </div>
  </>
);

JourneyDetailPage.Layout = (page) => <FullscreenLayout>{page}</FullscreenLayout>;

export default JourneyDetailPage;
