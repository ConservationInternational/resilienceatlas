import React, { useEffect, useState, useMemo } from 'react';
import { connect } from 'react-redux';
import { useCookies } from 'react-cookie';
import { useTour } from '@reactour/tour';
import { getServerSideTranslations } from 'i18n';

import FullscreenLayout from 'views/layouts/fullscreen';
import Sidebar from 'views/components/Sidebar';
import Legend from 'views/components/Legend';
import InfoWindow from 'views/components/InfoWindow';
import LoginRequiredWindow from 'views/components/LoginRequiredWindow';
import DownloadWindow from 'views/components/DownloadWindow';
import MapView from 'views/components/Map';
import MapLoadingScreen from 'views/components/Map/loading-screen';

import { LayerManagerProvider } from 'views/contexts/layerManagerCtx';

import { withTranslations, useSetServerSideTranslations } from 'utilities/hooks/transifex';
import type { NextPageWithLayout } from './_app';
import type { GetServerSidePropsContext } from 'next';
import type { RootState } from 'state/types';

const MapPage: NextPageWithLayout = ({ translations, setTranslations, isSidebarOpen }) => {
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

  // ? 350px is the width of the left sidebar
  const sidebarSize = useMemo(() => (isSidebarOpen ? 350 : 25), [isSidebarOpen]);

  return (
    <LayerManagerProvider>
      <Sidebar />
      <div className="l-content--fullscreen">
        {anyLayerLoading && (
          <MapLoadingScreen
            styles={{
              width: `calc(100% - ${sidebarSize}px)`,
              left: sidebarSize,
            }}
          />
        )}{' '}
        <MapView
          onLoadingLayers={(loaded) => {
            setAnyLayerLoading(loaded);
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

export default connect(
  (state: RootState) => ({ isSidebarOpen: state.ui.sidebar }),
  null,
)(withTranslations(MapPage));

export async function getServerSideProps(context: GetServerSidePropsContext) {
  const { translations } = await getServerSideTranslations(context);
  return {
    props: {
      translations,
    },
  };
}
