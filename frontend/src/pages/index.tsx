import HomepageSections from 'views/components/HomepageSections';

import MainLayout from 'views/layouts/main';

import type { NextPageWithLayout } from './_app';
import { getServerSideTranslations } from 'i18n';
import { useSetServerSideTranslations, withTranslations } from 'utilities/hooks/transifex';
import type { GetServerSidePropsContext } from 'next';

const Homepage: NextPageWithLayout = ({ translations, setTranslations }) => {
  useSetServerSideTranslations({ setTranslations, translations });

  return <HomepageSections />;
};

Homepage.Layout = (page, translations) => (
  <MainLayout pageTitle={translations['Welcome']}>{page}</MainLayout>
);

export default withTranslations(Homepage);

export async function getServerSideProps(context: GetServerSidePropsContext) {
  const { translations } = await getServerSideTranslations(context);
  return {
    props: {
      translations,
    },
  };
}
