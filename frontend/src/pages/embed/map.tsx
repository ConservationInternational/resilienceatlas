import { useState } from 'react';
import MapView from 'views/components/Map';
import { getServerSideTranslations } from 'i18n';
import { LayerManagerProvider } from 'views/contexts/layerManagerCtx';
import Loader from 'views/shared/Loader';
import EmbedLayout from 'views/layouts/embed';
import MapLoadingScreen from 'views/components/Map/loading-screen';
import { useSetServerSideTranslations, withTranslations } from 'utilities/hooks/transifex';

import type { NextPageWithLayout } from 'pages/_app';
import type { GetServerSidePropsContext } from 'next';

const EmbedPage: NextPageWithLayout = ({ translations, setTranslations }) => {
  useSetServerSideTranslations({ setTranslations, translations });
  const [anyLayerLoading, setAnyLayerLoading] = useState(false);

  return (
    <LayerManagerProvider>
      <div className="l-content--fullscreen">
        <MapLoadingScreen />
        {anyLayerLoading && <MapLoadingScreen />}
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
        <Loader />
      </div>
    </LayerManagerProvider>
  );
};

EmbedPage.Layout = (page, translations) => (
  <EmbedLayout pageTitle={translations['Map']}>{page}</EmbedLayout>
);

export default withTranslations(EmbedPage);

export async function getServerSideProps(context: GetServerSidePropsContext) {
  const { translations } = await getServerSideTranslations(context);
  return {
    props: {
      translations,
    },
  };
}
