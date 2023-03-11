import { useEffect, useMemo } from 'react';
import cx from 'classnames';
import Head from 'next/head';
import { connect } from 'react-redux';

import { load as loadSite } from 'state/modules/site';

import Header from './_header';
import Icons from './_icons';

type FullscreenLayoutProps = React.PropsWithChildren & {
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

const FullscreenLayout: React.FC<FullscreenLayoutProps> = ({ site, page, children, dispatch }) => {
  const { name, color, subdomain, header_theme, header_color, logo_url } = site;

  // Currently data fetching in Layouts are not supporting getServerSideProps
  // https://nextjs.org/docs/basic-features/layouts#data-fetching
  // NOTE: consider move this to every page that needs it using getServerSideProps
  useEffect(() => dispatch(loadSite()), [dispatch]);

  const pageTitle = useMemo(
    () => (name === 'Resilience Atlas' ? 'Resilience Atlas' : `${name} | Resilience Atlas`),
    [name],
  );

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
        <title>{pageTitle}</title>
        <style type="text/css">{`
        :root {
          --theme-color: ${color};
          --logo-url: url(${logo_url});
          --header-color: ${header_color};
        };
      `}</style>
      </Head>
      <Icons />
      <Header />
      <div className="l-main--fullscreen">{children}</div>
    </div>
  );
};

const mapStateToProps = ({ site }) => ({ site });

export default connect(mapStateToProps)(FullscreenLayout);
