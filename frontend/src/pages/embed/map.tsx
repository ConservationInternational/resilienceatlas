import MapView from 'views/components/Map';
import { LayerManagerProvider } from 'views/contexts/layerManagerCtx';
import Loader from 'views/shared/Loader';
import EmbedLayout from 'views/layouts/embed';
import { useSetServerSideTranslations, withTranslations } from 'utilities/hooks/transifex';
import type { NextPageWithLayout } from 'pages/_app';
import { getServerSideTranslations } from 'i18n';
import type { GetServerSidePropsContext } from 'next';

const EmbedPage: NextPageWithLayout = ({ translations, setTranslations }) => {
  useSetServerSideTranslations({ setTranslations, translations });

  return (
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
