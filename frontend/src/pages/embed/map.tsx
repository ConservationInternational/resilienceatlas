import Head from 'next/head';

import MapView from 'views/components/Map';
import { LayerManagerProvider } from 'views/contexts/layerManagerCtx';
import Loader from 'views/shared/Loader';
import EmbedLayout from 'views/layouts/embed';

import type { NextPageWithLayout } from 'pages/_app';

const EmbedPage: NextPageWithLayout = () => (
  <LayerManagerProvider>
    <Head>
      <title>Map</title>
    </Head>

    <div className="l-content--fillscreen">
      <MapView
        options={{
          map: {
            minZoom: 2,
            maxZoom: 25,
            zoomControl: false,
          },
        }}
      />
      <Loader />
    </div>
  </LayerManagerProvider>
);

EmbedPage.Layout = (page) => <EmbedLayout>{page}</EmbedLayout>;

export default EmbedPage;
