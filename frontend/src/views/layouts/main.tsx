import { useEffect } from 'react';
import cx from 'classnames';
import Head from 'next/head';
import { connect } from 'react-redux';

import { load as loadSite } from 'state/modules/site';

import Header from './_header';
import Footer from './_footer';

type MainLayoutProps = React.PropsWithChildren & {
  site?: {
    name: string;
    color: string;
    subdomain: string;
    header_theme: string;
    header_color: string;
    logo_url: string;
  };
  page?: string;
  dispatch?: (action: unknown) => void;
};

// Temporary
const bare = false;

const MainLayout: React.FC<MainLayoutProps> = ({ site, page, children, dispatch }) => {
  const { name, color, subdomain, header_theme, header_color, logo_url } = site;

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
      <Head>
        <title>{name} | Resilience Atlas</title>
        <style type="text/css">{`
        :root {
          --theme-color: ${color};
          --logo-url: url(${logo_url});
          --header-color: ${header_color};
        };
      `}</style>
      </Head>
      <Header />
      <div className="l-main-fullscreen">{children}</div>
      <Footer />
    </div>
  );
};

const mapStateToProps = ({ site }) => ({ site });

export default connect(mapStateToProps)(MainLayout);
