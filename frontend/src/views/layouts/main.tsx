import { useEffect } from 'react';
import cx from 'classnames';
import { connect } from 'react-redux';
import PrivacyBanner from 'views/components/PrivacyBanner';

import { load as loadSite } from 'state/modules/site';

import Head from './_head';
import Header from './_header';
import Footer from './_footer';

type MainLayoutProps = React.PropsWithChildren & {
  site?: {
    subdomain: string;
    header_theme: string;
  };
  pageTitle: string;
  page?: string;
  dispatch?: (action: unknown) => void;
};

// Temporary
const bare = false;

const MainLayout: React.FC<MainLayoutProps> = ({ site, page, pageTitle, children, dispatch }) => {
  const { subdomain, header_theme } = site;

  // Currently data fetching in Layouts are not supporting getServerSideProps
  // https://nextjs.org/docs/basic-features/layouts#data-fetching
  // NOTE: consider move this to every page that needs it using getServerSideProps
  useEffect(() => dispatch(loadSite()), [dispatch]);

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
    </div>
  );
};

const mapStateToProps = ({ site }) => ({ site });

export default connect(mapStateToProps)(MainLayout);
