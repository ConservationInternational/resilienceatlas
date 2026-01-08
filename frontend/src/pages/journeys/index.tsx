import JourneysIntrolist from 'views/components/JourneysIntrolist';
import MainLayout from 'views/layouts/main';
import { T } from '@transifex/react';
import { useSetServerSideTranslations, withTranslations } from 'utilities/hooks/transifex';
import type { NextPageWithLayout } from '../_app';
import { getServerSideTranslations } from 'i18n';

import type { GetServerSidePropsContext } from 'next';

const JourneysPage: NextPageWithLayout = ({ translations, setTranslations }) => {
  useSetServerSideTranslations({ setTranslations, translations });

  return (
    <div className="l-content">
      <div className="l-journey__index" id="journeyIndexView">
        <div className="m-journey__title">
          <h1>
            <T _str="Discover Journeys" />
          </h1>
        </div>

        <JourneysIntrolist />
      </div>
    </div>
  );
};

JourneysPage.Layout = (page, translations) => (
  <MainLayout pageTitle={translations['Journeys']}>{page}</MainLayout>
);

export default withTranslations(JourneysPage);

export async function getServerSideProps(context: GetServerSidePropsContext) {
  const { translations } = await getServerSideTranslations(context);
  return {
    props: {
      translations,
    },
  };
}
