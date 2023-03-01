import React, { FC, useEffect } from 'react';
import Helmet from 'react-helmet';
import { RouteComponentProps } from 'react-router-dom';

import MapView from '@components/Map';
import Sidebar from '@components/Sidebar';
import Legend from '@components/Legend';
import InfoWindow from '@components/InfoWindow';
import LoginRequiredWindow from '@components/LoginRequiredWindow';
import DownloadWindow from '@components/DownloadWindow';
import ShareModal from '@components/ShareModal';

import { LayerManagerProvider } from '@contexts/layerManagerCtx';

import Loader from '@shared/Loader';

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
