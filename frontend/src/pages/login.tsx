import Link from 'next/link';
import Head from 'next/head';
import { Row } from 'react-foundation';

import LoginForm from 'views/components/LoginForm';
import MainLayout from 'views/layouts/main';

import type { NextPageWithLayout } from './_app';

const LoginPage: NextPageWithLayout = () => (
  <div className="l-content">
    <Head>
      <title>Log in | Resilience Atlas</title>
    </Head>
    <Row>
      <div className="m-user-form">
        <h2>Log in</h2>

        <LoginForm />

        <Link href="/register">
          <a>Sign up</a>
        </Link>
      </div>
    </Row>
  </div>
);

LoginPage.Layout = (page) => <MainLayout>{page}</MainLayout>;

export default LoginPage;
