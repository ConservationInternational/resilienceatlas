import { useCookies } from 'react-cookie';
import React, { useEffect } from 'react';
import { useTour } from '@reactour/tour';

import FullscreenLayout from 'views/layouts/fullscreen';
import Sidebar from 'views/components/Sidebar';
import Legend from 'views/components/Legend';
import InfoWindow from 'views/components/InfoWindow';
import LoginRequiredWindow from 'views/components/LoginRequiredWindow';
import DownloadWindow from 'views/components/DownloadWindow';
import MapView from 'views/components/Map';

import { LayerManagerProvider } from 'views/contexts/layerManagerCtx';

import Loader from 'views/shared/Loader';

import type { NextPageWithLayout } from './_app';

const MapPage: NextPageWithLayout = () => {
  const [cookies, setCookie] = useCookies(['mapTour']);
  const { mapTour } = cookies;
  const { isOpen, setIsOpen } = useTour();

  // TODO: migrate this, how it works?
  // const { location: { state } } = props;
  // useEffect(() => {
  //   if (state && state.downloadLayerUrl) {
  //     DownloadWindow.show(state.downloadLayerUrl);
  //   }
  // }, []);

  useEffect(() => {
    // Showing the map tour only once,
    // to show it again remove cookies from the browser
    if (!mapTour && !isOpen) {
      setCookie('mapTour', 'enabled');
      setIsOpen(true);
    }
  }, [isOpen, mapTour, setCookie, setIsOpen]);

  return (
    <LayerManagerProvider>
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
      </div>
    </LayerManagerProvider>
  );
};

MapPage.Layout = (page) => <FullscreenLayout pageTitle="Map">{page}</FullscreenLayout>;

export default MapPage;
