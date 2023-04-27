/* eslint-disable @next/next/no-img-element */
import AboutSections from 'views/components/AboutSections';
import MainLayout from 'views/layouts/main';
import { getServerSideTranslations } from 'i18n';
import { useSetServerSideTranslations, withTranslations } from 'utilities/hooks/transifex';
import type { GetServerSidePropsContext } from 'next';
import type { NextPageWithLayout } from './_app';

const AboutPage: NextPageWithLayout = ({ translations, setTranslations }) => {
  useSetServerSideTranslations({ setTranslations, translations });
  return <AboutSections />;
};

AboutPage.Layout = (page, translations) => (
  <MainLayout pageTitle={translations['About']}>{page}</MainLayout>
);

export default withTranslations(AboutPage);

export async function getServerSideProps(context: GetServerSidePropsContext) {
  const { translations } = await getServerSideTranslations(context);
  return {
    props: {
      translations,
    },
  };
}
