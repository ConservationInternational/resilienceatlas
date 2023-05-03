import { useEffect } from 'react';
import Link from 'next/link';
import { Row } from 'react-foundation';
import { useRouter } from 'next/router';
import { connect } from 'react-redux';
import { T } from '@transifex/react';
import { setTranslations } from 'state/modules/translations';
import { loadUserData } from 'state/modules/user';
import { isAuthenticated } from 'utilities/authenticated';
import EditProfileForm from 'views/components/EditProfileForm';
import MainLayout from 'views/layouts/main';
import { getServerSideTranslations } from 'i18n';
import { useSetServerSideTranslations } from 'utilities/hooks/transifex';
import type { GetServerSidePropsContext } from 'next';
import type { NextPageWithLayout, ResilienceAppProps } from './_app';

type MePageProps = ResilienceAppProps & {
  user: {
    auth_token: string;
    data?: Record<string, unknown>;
  };
  loadUserData: () => void;
};

const MePage: NextPageWithLayout<MePageProps> = ({
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
    if (!authenticated && router.isReady) router.push('/');
  }, [authenticated, router]);

  return (
    <div className="l-content">
      <Row>
        <div className="m-user-form">
          {!user.data && <div className="is-loading" />}

          {!!user.data && (
            <>
              <h2>
                {!user.data && <T _str="Edit profile" />}
                {!!user.data && (
                  <T
                    _str="Edit {first_name} {last_name}"
                    first_name={user.data.first_name}
                    last_name={user.data.last_name}
                  />
                )}
              </h2>

              <EditProfileForm />

              <Link href="/profile-settings">
                <a>
                  <T _str="Manage account" />
                </a>
              </Link>
            </>
          )}
        </div>
      </Row>
    </div>
  );
};

MePage.Layout = (page, translations) => (
  <MainLayout pageTitle={translations['Me']}>{page}</MainLayout>
);

const mapStateToProps = (state) => ({ user: state.user });
const mapDispatchToProps = {
  setTranslations,
  loadUserData,
};

export default connect(mapStateToProps, mapDispatchToProps)(MePage);

export async function getServerSideProps(context: GetServerSidePropsContext) {
  const { translations } = await getServerSideTranslations(context);
  return {
    props: {
      translations,
    },
  };
}
