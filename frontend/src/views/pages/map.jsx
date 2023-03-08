import type { FC } from 'react';
import React, { useEffect } from 'react';
import Helmet from 'react-helmet';
import type { RouteComponentProps } from 'react-router-dom';

import MapView from 'views/components/Map';
import Sidebar from 'views/components/Sidebar';
import Legend from 'views/components/Legend';
import InfoWindow from 'views/components/InfoWindow';
import LoginRequiredWindow from 'views/components/LoginRequiredWindow';
import DownloadWindow from 'views/components/DownloadWindow';
import ShareModal from 'views/components/ShareModal';

import { LayerManagerProvider } from 'views/contexts/layerManagerCtx';

import Loader from 'views/shared/Loader';

const MapPage: FC<RouteComponentProps> = ({ location: { state } }) => {
  useEffect(() => {
    if (state && state.downloadLayerUrl) {
      DownloadWindow.show(state.downloadLayerUrl);
    }
  }, []);
  return (
    <LayerManagerProvider>
      <Helmet title="Map" />
      <Sidebar />
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
        <Legend />
        <InfoWindow />
        <DownloadWindow />
        <LoginRequiredWindow />
        <ShareModal />
      </div>
    </LayerManagerProvider>
  );
};

export default MapPage;
