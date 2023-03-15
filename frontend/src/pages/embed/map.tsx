import MapView from 'views/components/Map';
import { LayerManagerProvider } from 'views/contexts/layerManagerCtx';
import Loader from 'views/shared/Loader';
import EmbedLayout from 'views/layouts/embed';

import type { NextPageWithLayout } from 'pages/_app';

const EmbedPage: NextPageWithLayout = () => (
  <LayerManagerProvider>
    <div className="l-content--fullscreen">
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

EmbedPage.Layout = (page) => <EmbedLayout pageTitle="Map">{page}</EmbedLayout>;

export default EmbedPage;
