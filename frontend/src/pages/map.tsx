import { useCookies } from 'react-cookie';
import React, { useEffect, useState } from 'react';
import { useTour } from '@reactour/tour';

import FullscreenLayout from 'views/layouts/fullscreen';
import Sidebar from 'views/components/Sidebar';
import Legend from 'views/components/Legend';
import InfoWindow from 'views/components/InfoWindow';
import LoginRequiredWindow from 'views/components/LoginRequiredWindow';
import DownloadWindow from 'views/components/DownloadWindow';
import MapView from 'views/components/Map';
import MapLoadingScreen from 'views/components/Map/loading-screen';

import { LayerManagerProvider } from 'views/contexts/layerManagerCtx';

import type { NextPageWithLayout } from './_app';
import { getServerSideTranslations } from 'i18n';
import { withTranslations, useSetServerSideTranslations } from 'utilities/hooks/transifex';
import type { GetServerSidePropsContext } from 'next';

const MapPage: NextPageWithLayout = ({ translations, setTranslations }) => {
  const [cookies, setCookie] = useCookies(['mapTour']);
  const { mapTour } = cookies;
  const { isOpen, setIsOpen } = useTour();
  const [anyLayerLoading, setAnyLayerLoading] = useState(false);

  // TODO: migrate this, how it works?
  // const { location: { state } } = props;
  // useEffect(() => {
  //   if (state && state.downloadLayerUrl) {
  //     DownloadWindow.show(state.downloadLayerUrl);
  //   }
  // }, []);
  useSetServerSideTranslations({ setTranslations, translations });

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
        {anyLayerLoading && (
          <MapLoadingScreen
            styles={{
              // 350px is the width of the left sidebar
              width: 'calc(100% - 350px)',
              left: 350,
            }}
          />
        )}
        <MapView
          onLoadingLayers={(loaded) => {
            setAnyLayerLoading(loaded);
          }}
          options={{
            map: {
              minZoom: 2,
              maxZoom: 25,
              zoomControl: false,
            },
          }}
        />
        <Legend />
        <InfoWindow />
        <DownloadWindow />
        <LoginRequiredWindow />
      </div>
    </LayerManagerProvider>
  );
};

MapPage.Layout = (page, translations) => (
  <FullscreenLayout pageTitle={translations['Map']}>{page}</FullscreenLayout>
);

export default withTranslations(MapPage);

export async function getServerSideProps(context: GetServerSidePropsContext) {
  const { translations } = await getServerSideTranslations(context);
  return {
    props: {
      translations,
    },
  };
}
