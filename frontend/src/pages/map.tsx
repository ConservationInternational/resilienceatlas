import React, { useEffect, useState, useMemo } from 'react';
import { connect } from 'react-redux';
import { useCookies } from 'react-cookie';
import { useTour } from '@reactour/tour';
import { getServerSideTranslations } from 'i18n';

import FullscreenLayout from 'views/layouts/fullscreen';
import Sidebar from 'views/components/Sidebar';
import MobileSidebarToggle from 'views/components/MobileSidebarToggle';
import Legend from 'views/components/Legend';
import InfoWindow from 'views/components/InfoWindow';
import LoginRequiredWindow from 'views/components/LoginRequiredWindow';
import DownloadWindow from 'views/components/DownloadWindow';
import MapView from 'views/components/Map';
import MapLoadingScreen from 'views/components/Map/loading-screen';

import { LayerManagerProvider } from 'views/contexts/layerManagerCtx';
import { useCookiesConsent } from 'utilities/hooks/useCookiesConsent';

import { withTranslations, useSetServerSideTranslations } from 'utilities/hooks/transifex';
import type { NextPageWithLayout } from './_app';
import type { GetServerSidePropsContext } from 'next';
import type { RootState } from 'state/types';

const MapPage: NextPageWithLayout = ({ translations, setTranslations, isSidebarOpen }) => {
  const [cookies, setCookie] = useCookies(['mapTour']);
  const { mapTour } = cookies;
  const { isOpen, setIsOpen } = useTour();
  const [anyLayerLoading, setAnyLayerLoading] = useState(false);
  const [mapControlsReady, setMapControlsReady] = useState(false);
  const { consentDate } = useCookiesConsent();

  // TODO: migrate this, how it works?
  // const { location: { state } } = props;
  // useEffect(() => {
  //   if (state && state.downloadLayerUrl) {
  //     DownloadWindow.show(state.downloadLayerUrl);
  //   }
  // }, []);
  useSetServerSideTranslations({ setTranslations, translations });

  // Wait for map controls to be rendered before allowing tour to start
  useEffect(() => {
    const checkMapControls = () => {
      const mapControls = document.querySelector('.c-map-controls');
      if (mapControls) {
        setMapControlsReady(true);
        return true;
      }
      return false;
    };

    // Check immediately
    if (checkMapControls()) return;

    // Poll for map controls to appear (they're loaded dynamically)
    const interval = setInterval(() => {
      if (checkMapControls()) {
        clearInterval(interval);
      }
    }, 100);

    // Cleanup after 10 seconds max
    const timeout = setTimeout(() => {
      clearInterval(interval);
    }, 10000);

    return () => {
      clearInterval(interval);
      clearTimeout(timeout);
    };
  }, []);

  useEffect(() => {
    // Showing the map tour only once,
    // to show it again remove cookies from the browser
    // Wait for: 1) cookie consent to be handled, 2) map controls to be ready
    if (!mapTour && !isOpen && consentDate && mapControlsReady) {
      setCookie('mapTour', 'enabled');
      setIsOpen(true);
    }
  }, [isOpen, mapTour, setCookie, setIsOpen, consentDate, mapControlsReady]);

  // ? 350px is the width of the left sidebar
  const sidebarSize = useMemo(() => (isSidebarOpen ? 350 : 25), [isSidebarOpen]);

  return (
    <LayerManagerProvider>
      {/* Mobile sidebar toggle - outside sidebar to stay visible when collapsed */}
      <MobileSidebarToggle />
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

// Apply withTranslations first, which preserves the Layout property
const TranslatedMapPage = withTranslations(MapPage);

// Create the connected component and preserve the Layout property
const ConnectedMapPage = connect(
  (state: RootState) => ({ isSidebarOpen: state.ui.sidebar }),
  null,
)(TranslatedMapPage);

// Preserve the Layout property on the final exported component
// This is critical for the Next.js layout pattern in _app.tsx
ConnectedMapPage.Layout = MapPage.Layout;

export default ConnectedMapPage;

export async function getServerSideProps(context: GetServerSidePropsContext) {
  const { translations } = await getServerSideTranslations(context);
  return {
    props: {
      translations,
    },
  };
}
