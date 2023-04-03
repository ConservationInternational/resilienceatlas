import Link from 'next/link';
import { Row } from 'react-foundation';

import LoginForm from 'views/components/LoginForm';
import MainLayout from 'views/layouts/main';
import { T } from '@transifex/react';

import type { NextPageWithLayout } from './_app';

const LoginPage: NextPageWithLayout = () => (
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

LoginPage.Layout = (page) => <MainLayout pageTitle="Sign in">{page}</MainLayout>;

export default LoginPage;
