import React, { useEffect } from 'react';

import FullscreenLayout from 'views/layouts/fullscreen';
import MapView from 'views/components/Map';
import Sidebar from 'views/components/Sidebar';
import Legend from 'views/components/Legend';
import InfoWindow from 'views/components/InfoWindow';
import LoginRequiredWindow from 'views/components/LoginRequiredWindow';
import DownloadWindow from 'views/components/DownloadWindow';
import ShareModal from 'views/components/ShareModal';

import { LayerManagerProvider } from 'views/contexts/layerManagerCtx';

import Loader from 'views/shared/Loader';

import type { NextPageWithLayout } from './_app';

const MapPage: NextPageWithLayout = () => {
  // const { location: { state } } = props;
  // useEffect(() => {
  //   if (state && state.downloadLayerUrl) {
  //     DownloadWindow.show(state.downloadLayerUrl);
  //   }
  // }, []);

  return (
    <LayerManagerProvider>
      <Sidebar />
      <div className="l-content--fullscreen">
        {/* <MapView
          options={{
            map: {
              minZoom: 2,
              maxZoom: 25,
              zoomControl: false,
            },
          }}
        /> */}
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

MapPage.Layout = (page) => <FullscreenLayout pageTitle="Map">{page}</FullscreenLayout>;

export default MapPage;
