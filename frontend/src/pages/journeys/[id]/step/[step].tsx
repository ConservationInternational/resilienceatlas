import { useEffect } from 'react';
import Journey from 'views/components/Journey';
import FullscreenLayout from 'views/layouts/fullscreen';
import { getServerSideTranslations } from 'i18n';

import type { GetServerSidePropsContext } from 'next';

import type { NextPageWithLayout } from '../../../_app';
import { useSetServerSideTranslations, withTranslations } from 'utilities/hooks/transifex';

const JourneyDetailPage: NextPageWithLayout = ({ translations, setTranslations }) => {
  useSetServerSideTranslations({ setTranslations, translations });

  useEffect(() => {
    // Store the translations in redux for child components
    setTranslations(translations);
  }, [setTranslations, translations]);
  return (
    <div className="l-content">
      <Journey />
    </div>
  );
};

JourneyDetailPage.Layout = (page, translations) => (
  <FullscreenLayout pageTitle={translations['Journey Step']}>{page}</FullscreenLayout>
);

export default withTranslations(JourneyDetailPage);

export async function getServerSideProps(context: GetServerSidePropsContext) {
  const { translations } = await getServerSideTranslations(context);
  return {
    props: {
      translations,
    },
  };
}
