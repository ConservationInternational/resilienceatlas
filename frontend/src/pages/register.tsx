import { Row } from 'views/components/Grid';

import SignupForm from 'views/components/SignupForm';
import MainLayout from 'views/layouts/main';
import { T } from '@transifex/react';
import { getServerSideTranslations } from 'i18n';
import { withTranslations, useSetServerSideTranslations } from 'utilities/hooks/transifex';
import type { GetServerSidePropsContext } from 'next';
import type { NextPageWithLayout } from './_app';

const SignupPage: NextPageWithLayout = ({ setTranslations, translations }) => {
  useSetServerSideTranslations({ setTranslations, translations });

  return (
    <div className="l-content">
      <Row>
        <div className="m-user-form">
          <h2>
            <T _str="Sign up" />
          </h2>

          <SignupForm />
        </div>
      </Row>
    </div>
  );
};

SignupPage.Layout = (page, translations) => (
  <MainLayout pageTitle={translations['Sign up']}>{page}</MainLayout>
);

export default withTranslations(SignupPage);
export async function getServerSideProps(context: GetServerSidePropsContext) {
  const { translations } = await getServerSideTranslations(context);
  return {
    props: {
      translations,
    },
  };
}
