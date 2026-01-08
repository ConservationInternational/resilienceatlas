import { useEffect } from 'react';
import Journey from 'views/components/Journey';
import FullscreenLayout from 'views/layouts/fullscreen';
import { getServerSideTranslations } from 'i18n';
import { get } from 'state/utils/api';
import { URL_JOURNEYS } from 'state/modules/journeys';
import type { GetServerSidePropsContext } from 'next';
import Head from 'next/head';

import type { JourneyNextPageWithLayout } from '../../../_app';
import { useSetServerSideTranslations, withTranslations } from 'utilities/hooks/transifex';

const JourneyDetailPage: JourneyNextPageWithLayout = ({
  translations,
  setTranslations,
  published,
}) => {
  useSetServerSideTranslations({ setTranslations, translations });

  useEffect(() => {
    // Store the translations in redux for child components
    setTranslations(translations);
  }, [setTranslations, translations]);
  return (
    <>
      <Head>
        {!published && <meta name="robots" content="noindex, nofollow, noimageindex, noarchive" />}
      </Head>
      <div className="l-content">
        <Journey />
      </div>
    </>
  );
};

JourneyDetailPage.Layout = (page, translations) => (
  <FullscreenLayout pageTitle={translations['Journey Step']}>{page}</FullscreenLayout>
);

export default withTranslations(JourneyDetailPage);

export async function getServerSideProps(context: GetServerSidePropsContext) {
  const { translations } = await getServerSideTranslations(context);

  // We need to check if the journey is published server side
  const { id } = context.query;
  const result = await get(`${URL_JOURNEYS}/${id}`, {});
  const { published } = result?.data?.data?.attributes || {};

  return {
    props: {
      translations,
      published,
    },
  };
}
