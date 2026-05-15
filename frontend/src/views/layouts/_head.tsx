import Head from 'next/head';
import { connect } from 'react-redux';

type CustomHeadProps = {
  pageTitle?: React.ReactNode;
  site?: {
    name: string;
    color: string;
    header_color: string;
    logo_url: string;
    logo_urls: string[];
    favicon_url: string;
    loaded: boolean;
  };
};

const CustomHead: React.FC<CustomHeadProps> = ({ pageTitle, site }) => {
  // Safely destructure site with default values to prevent errors during SSR/hydration
  const {
    name = '',
    color = '',
    header_color = '',
    logo_url = '',
    favicon_url = '',
    loaded = false,
  } = site || {};

  return (
    <Head>
      <title>{`${name} | ${pageTitle}`}</title>
      {loaded && favicon_url && <link rel="icon" href={favicon_url} />}
      {loaded && (
        <style type="text/css">
          {`
            :root {
              --theme-color: ${color};
              --logo-url: url(${logo_url});
              --header-color: ${header_color};
            };
          `}
        </style>
      )}
    </Head>
  );
};

const mapStateToProps = ({ site }) => ({ site });

export default connect(mapStateToProps)(CustomHead);
