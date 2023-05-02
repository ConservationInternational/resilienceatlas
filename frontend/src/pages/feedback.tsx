import FullscreenLayout from 'views/layouts/fullscreen';

import type { NextPageWithLayout } from './_app';
import { getServerSideTranslations } from 'i18n';
import { useSetServerSideTranslations, withTranslations } from 'utilities/hooks/transifex';
import type { GetServerSidePropsContext } from 'next';

import FeedbackForm from 'views/components/FeedbackForm';

const Feedback: NextPageWithLayout = ({ translations, setTranslations }) => {
  useSetServerSideTranslations({ setTranslations, translations });

  return <FeedbackForm />;
};

Feedback.Layout = (page, translations) => (
  <FullscreenLayout pageTitle={translations['Feedback']}>{page}</FullscreenLayout>
);

export default withTranslations(Feedback);

export async function getServerSideProps(context: GetServerSidePropsContext) {
  const { translations } = await getServerSideTranslations(context);
  const { query } = context;

  // Prevent feedback page from being accessed directly
  if (!query.returnPath) {
    return {
      notFound: true,
    };
  }

  return {
    props: {
      translations,
    },
  };
}
