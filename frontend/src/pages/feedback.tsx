import { getServerSideTranslations } from 'i18n';
import type { GetServerSidePropsContext } from 'next';

import type { NextPageWithLayout } from './_app';
import { useSetServerSideTranslations, withTranslations } from 'utilities/hooks/transifex';
import { getSubdomainFromURL } from 'utilities/getSubdomain';

import FullscreenLayout from 'views/layouts/fullscreen';
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
  const subdomain = getSubdomainFromURL(context.req.headers.host);
  const { translations } = await getServerSideTranslations(context);

  // Feedback is only available for the main atlas
  if (subdomain) {
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
