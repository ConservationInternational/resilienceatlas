import Journey from 'views/components/Journey';
import FullscreenLayout from 'views/layouts/fullscreen';

import type { NextPageWithLayout } from '../../../_app';

const JourneyDetailPage: NextPageWithLayout = () => (
  <div className="l-content">
    <Journey />
  </div>
);

JourneyDetailPage.Layout = (page) => (
  <FullscreenLayout pageTitle="Journey Step">{page}</FullscreenLayout>
);

export default JourneyDetailPage;
