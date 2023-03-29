import { Row } from 'react-foundation';

import SignupForm from 'views/components/SignupForm';
import MainLayout from 'views/layouts/main';
import { T } from '@transifex/react';

import type { NextPageWithLayout } from './_app';

const SignupPage: NextPageWithLayout = () => (
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

SignupPage.Layout = (page) => <MainLayout pageTitle="Sign up">{page}</MainLayout>;

export default SignupPage;
