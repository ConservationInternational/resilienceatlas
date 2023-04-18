import MainLayout from 'views/layouts/main';
import { T } from '@transifex/react';

import type { NextPageWithLayout } from './_app';
import { getServerSideTranslations } from 'i18n';

import type { GetServerSidePropsContext } from 'next';
import { useSetServerSideTranslations, withTranslations } from 'utilities/hooks/transifex';

const ShinnyAppPage: NextPageWithLayout = ({ translations, setTranslations }) => {
  useSetServerSideTranslations({ setTranslations, translations });

  return (
    <div className="l-content">
      <div className="l-journey__index" id="journeyIndexView">
        <div className="m-journey__title">
          <h1>
            <T _str="Shinny App" />
          </h1>
        </div>

        <div>
          <iframe
            src="https://sparc-apps.shinyapps.io/irrecoverable_carbon_biodiversity_app_internal/"
            width="99%"
            height="1000px"
          />
        </div>
      </div>
    </div>
  );
};

ShinnyAppPage.Layout = (page, translations) => (
  <MainLayout pageTitle={translations['Shinny App']}>{page}</MainLayout>
);

export default withTranslations(ShinnyAppPage);

export async function getServerSideProps(context: GetServerSidePropsContext) {
  const { translations } = await getServerSideTranslations(context);
  return {
    props: {
      translations,
    },
  };
}
