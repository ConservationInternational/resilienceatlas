import { useEffect } from 'react';
import Link from 'next/link';
import { Row } from 'react-foundation';
import { useRouter } from 'next/router';
import { connect } from 'react-redux';

import { isAuthenticated } from 'utilities/authenticated';
import EditProfileForm from 'views/components/EditProfileForm';
import MainLayout from 'views/layouts/main';

import type { NextPageWithLayout } from './_app';

const MePage: NextPageWithLayout = ({ user }) => {
  const router = useRouter();
  const authenticated = isAuthenticated(user);

  useEffect(() => {
    if (!authenticated && router.isReady) router.push('/');
  }, [authenticated, router]);

  return (
    <div className="l-content">
      <Row>
        <div className="m-user-form">
          <h2>
            Edit {user.first_name} {user.last_name}
          </h2>

          <EditProfileForm />

          <Link href="/profile-settings">
            <a>Manage account</a>
          </Link>
        </div>
      </Row>
    </div>
  );
};

MePage.Layout = (page) => <MainLayout pageTitle="Me">{page}</MainLayout>;

const mapStateToProps = (state) => ({ user: state.user });

export default connect(mapStateToProps)(MePage);
