import { useEffect } from 'react';
import cx from 'classnames';
import { connect } from 'react-redux';
import PrivacyBanner from 'views/components/PrivacyBanner';

import { load as loadSite } from 'state/modules/site';
import { useRouter } from 'next/router';

import Head from './_head';
import Header from './_header';
import Footer from './_footer';
import Icons from './_icons';
import type { TypedT } from 'types/transifex';

type MainLayoutProps = React.PropsWithChildren & {
  site?: {
    subdomain: string;
    header_theme: string;
  };
  pageTitle: string | TypedT;
  page?: string;
  dispatch?: (action: unknown) => void;
};

// Temporary
const bare = false;

const MainLayout: React.FC<MainLayoutProps> = (props) => {
  const { site, page, pageTitle, children, dispatch } = props;
  // Provide default values to prevent errors when site is undefined during SSR
  const { subdomain = '', header_theme = '' } = site || {};
  const router = useRouter();
  const { locale } = router;
  // Currently data fetching in Layouts are not supporting getServerSideProps
  // https://nextjs.org/docs/basic-features/layouts#data-fetching
  // NOTE: consider move this to every page that needs it using getServerSideProps
  useEffect(() => {
    dispatch(loadSite(locale));
  }, [dispatch, locale]);
  return (
    <div
      className={cx(
        `is-${subdomain}`,
        `is-${header_theme}`,
        `is-${bare ? '' : 'not-'}bare`,
        `${subdomain === 'atlas' ? 'has' : 'no'}-sidebar-logo`,
        { 'is-indicators': !!subdomain, [`is-${page}-page`]: page },
      )}
    >
      <Head pageTitle={pageTitle} />
      <Header />
      <div className="l-main-fullscreen">{children}</div>
      <Footer />
      <PrivacyBanner />
      <Icons />
    </div>
  );
};

const mapStateToProps = ({ site }) => ({ site });

export default connect(mapStateToProps)(MainLayout);
