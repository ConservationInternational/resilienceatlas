import { useRouter } from 'next/router';
import { Row } from 'react-foundation';
import { connect } from 'react-redux';

import ProfileSettingsForm from 'views/components/ProfileSettingsForm';
import MainLayout from 'views/layouts/main';

import type { NextPageWithLayout } from './_app';

const ProfileSettingsPage: NextPageWithLayout = ({ user }) => {
  const router = useRouter();

  return (
    <div className="l-content">
      <Row>
        <div className="m-user-form">
          <h2>
            Edit {user.first_name} {user.last_name}
          </h2>
          <ProfileSettingsForm />
          <h3>Cancel my account</h3>

          <p>Unhappy?</p>

          <input type="submit" value="Cancel my account" />

          <button type="button" onClick={router.back}>
            Back
          </button>
        </div>
      </Row>
    </div>
  );
};

ProfileSettingsPage.Layout = (page) => <MainLayout pageTitle="Profile settings">{page}</MainLayout>;

const mapStateToProps = (state) => ({ user: state.user });

export default connect(mapStateToProps)(ProfileSettingsPage);
