import { useEffect, useMemo } from 'react';
import cx from 'classnames';
import { connect } from 'react-redux';

import { load as loadSite } from 'state/modules/site';

import Icons from './_icons';
import Head from './_head';

type ReportLayoutProps = React.PropsWithChildren & {
  site?: {
    subdomain: string;
    header_theme: string;
  };
  pageTitle: string;
  dispatch?: (action: unknown) => void;
};

// Temporary
const bare = false;
const page = 'report';

const ReportLayout: React.FC<ReportLayoutProps> = ({ site, pageTitle, children, dispatch }) => {
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
      <div className="l-main">{children}</div>
    </div>
  );
};

const mapStateToProps = ({ site }) => ({ site });

export default connect(mapStateToProps)(ReportLayout);
