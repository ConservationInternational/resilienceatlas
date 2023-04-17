import Link from 'next/link';
import { Row } from 'react-foundation';

import LoginForm from 'views/components/LoginForm';
import MainLayout from 'views/layouts/main';
import { T } from '@transifex/react';

import type { NextPageWithLayout } from './_app';
import { getServerSideTranslations } from 'i18n';
import { withTranslations, useSetServerSideTranslations } from 'utilities/hooks/transifex';
import type { GetServerSidePropsContext } from 'next';

const LoginPage: NextPageWithLayout = ({ translations, setTranslations }) => {
  useSetServerSideTranslations({ setTranslations, translations });

  return (
    <div className="l-content">
      <Row>
        <div className="m-user-form">
          <h2>
            <T _str="Log in" />
          </h2>

          <LoginForm />

          <Link href="/register">
            <a>
              <T _str="Sign up" />
            </a>
          </Link>
        </div>
      </Row>
    </div>
  );
};

LoginPage.Layout = (page, translations) => (
  <MainLayout pageTitle={translations['Sign in']}>{page}</MainLayout>
);

export default withTranslations(LoginPage);

export async function getServerSideProps(context: GetServerSidePropsContext) {
  const { translations } = await getServerSideTranslations(context);
  return {
    props: {
      translations,
    },
  };
}
