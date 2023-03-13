import { useEffect } from 'react';
import cx from 'classnames';
import { connect } from 'react-redux';

import { load as loadSite } from 'state/modules/site';

import Head from './_head';
import Header from './_header';
import Icons from './_icons';

type EmbedPageProps = React.PropsWithChildren & {
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

const EmbedPage: React.FC<EmbedPageProps> = ({ site, page, pageTitle, children, dispatch }) => {
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
      <Icons />
      <Header />
      <div className="l-main--embed">{children}</div>
    </div>
  );
};

const mapStateToProps = ({ site }) => ({ site });

export default connect(mapStateToProps)(EmbedPage);
