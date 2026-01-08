import { useEffect } from 'react';
import { useRouter } from 'next/router';
import { Row } from 'views/components/Grid';
import { connect } from 'react-redux';
import { setTranslations } from 'state/modules/translations';
import { isAuthenticated } from 'utilities/authenticated';
import ProfileSettingsForm from 'views/components/ProfileSettingsForm';
import MainLayout from 'views/layouts/main';
import { T } from '@transifex/react';
import { getServerSideTranslations } from 'i18n';
import { useSetServerSideTranslations } from 'utilities/hooks/transifex';
import type { GetServerSidePropsContext } from 'next';
import type { NextPageWithLayout, ResilienceAppProps } from './_app';
import { loadUserData } from 'state/modules/user';

type ProfileSettingsPageProps = ResilienceAppProps & {
  user: {
    auth_token: string;
    data?: Record<string, unknown>;
  };
  loadUserData: () => void;
};

const ProfileSettingsPage: NextPageWithLayout<ProfileSettingsPageProps> = ({
  user,
  translations,
  setTranslations,
  loadUserData,
}) => {
  useSetServerSideTranslations({ setTranslations, translations });

  const router = useRouter();
  const authenticated = isAuthenticated(user);

  useEffect(() => {
    if (!user.data && !!user.auth_token) {
      loadUserData();
    }
  }, [user, loadUserData]);

  useEffect(() => {
    if (!authenticated) router.push('/');
  }, [authenticated, router]);

  return (
    <div className="l-content">
      <Row>
        <div className="m-user-form">
          {!user.data && <div className="is-loading" />}

          {!!user.data && (
            <>
              <h2>
                <T
                  _str="Edit {first_name} {last_name}"
                  first_name={user.data.first_name}
                  last_name={user.data.last_name}
                />
              </h2>
              <ProfileSettingsForm />
              {/* <h3>
                <T _str="Delete my account" />
              </h3>

              <p>
                <T _str="This action cannot be undone." />
              </p>

              <input type="submit" value={t('Delete my account')} /> */}

              <button type="button" onClick={router.back}>
                <T _str="Back" />
              </button>
            </>
          )}
        </div>
      </Row>
    </div>
  );
};

ProfileSettingsPage.Layout = (page, translations) => (
  <MainLayout pageTitle={translations['Profile settings']}>{page}</MainLayout>
);

const mapStateToProps = (state) => ({ user: state.user });
const mapDispatchToProps = {
  setTranslations,
  loadUserData,
};

// Create the connected component and preserve the Layout property
const ConnectedProfileSettingsPage = connect(
  mapStateToProps,
  mapDispatchToProps,
)(ProfileSettingsPage);

// Preserve the Layout property on the final exported component
// This is critical for the Next.js layout pattern in _app.tsx
ConnectedProfileSettingsPage.Layout = ProfileSettingsPage.Layout;

export default ConnectedProfileSettingsPage;

export async function getServerSideProps(context: GetServerSidePropsContext) {
  const { translations } = await getServerSideTranslations(context);
  return {
    props: {
      translations,
    },
  };
}
