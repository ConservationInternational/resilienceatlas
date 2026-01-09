import { useEffect } from 'react';
import cx from 'classnames';
import { connect } from 'react-redux';
import PrivacyBanner from 'views/components/PrivacyBanner';
import { useRouter } from 'next/router';

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
      <Icons />
      <div className="l-main">{children}</div>
      <PrivacyBanner />
    </div>
  );
};

const mapStateToProps = ({ site }) => ({ site });

export default connect(mapStateToProps)(ReportLayout);
