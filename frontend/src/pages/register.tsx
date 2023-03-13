import Head from 'next/head';
import { Row } from 'react-foundation';

import SignupForm from 'views/components/SignupForm';
import MainLayout from 'views/layouts/main';

import type { NextPageWithLayout } from './_app';

const SignupPage: NextPageWithLayout = () => (
  <div className="l-content">
    <Head>
      <title>Sign up | Resilience Atlas</title>
    </Head>
    <Row>
      <div className="m-user-form">
        <h2>Sign up</h2>

        <SignupForm />
      </div>
    </Row>
  </div>
);

SignupPage.Layout = (page) => <MainLayout>{page}</MainLayout>;

export default SignupPage;
