import { useEffect } from 'react';
import { useRouter } from 'next/router';
import { Row } from 'react-foundation';
import { connect } from 'react-redux';
import { setTranslations } from 'state/modules/translations';
import { isAuthenticated } from 'utilities/authenticated';
import ProfileSettingsForm from 'views/components/ProfileSettingsForm';
import MainLayout from 'views/layouts/main';
import { T } from '@transifex/react';
import { getServerSideTranslations } from 'i18n';
import { useSetServerSideTranslations } from 'utilities/hooks/transifex';
import type { GetServerSidePropsContext } from 'next';
import type { NextPageWithLayout } from './_app';

const ProfileSettingsPage: NextPageWithLayout = ({ user, setTranslations, translations }) => {
  useSetServerSideTranslations({ setTranslations, translations });

  const router = useRouter();
  const authenticated = isAuthenticated(user);

  useEffect(() => {
    if (!authenticated) router.push('/');
  }, [authenticated, router]);

  return (
    <div className="l-content">
      <Row>
        <div className="m-user-form">
          <h2>
            <T
              _str="Edit {first_name} {last_name}"
              first_name={user.first_name}
              last_name={user.last_name}
            />
          </h2>
          <ProfileSettingsForm />
          <h3>
            <T _str="Cancel my account" />
          </h3>

          <p>
            <T _str="Unhappy?" />
          </p>

          <input type="submit" value="Cancel my account" />

          <button type="button" onClick={router.back}>
            <T _str="Back" />
          </button>
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
};
export default connect(mapStateToProps, mapDispatchToProps)(ProfileSettingsPage);

export async function getServerSideProps(context: GetServerSidePropsContext) {
  const { translations } = await getServerSideTranslations(context);
  return {
    props: {
      translations,
    },
  };
}
