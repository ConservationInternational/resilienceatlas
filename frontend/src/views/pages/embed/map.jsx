import React from 'react';
import Helmet from 'react-helmet';

import MapView from '@components/Map';

import { LayerManagerProvider } from '@contexts/layerManagerCtx';

import Loader from '@shared/Loader';

const MapPage = () => (
  <LayerManagerProvider>
    <Helmet title="Map" />

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

export default MapPage;
