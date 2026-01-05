import Head from 'next/head';
import { connect } from 'react-redux';

type CustomHeadProps = {
  pageTitle?: React.ReactNode;
  site?: {
    name: string;
    color: string;
    header_color: string;
    logo_url: string;
  };
};

const CustomHead: React.FC<CustomHeadProps> = ({ pageTitle, site }) => {
  // Safely destructure site with default values to prevent errors during SSR/hydration
  const { name = '', color = '', header_color = '', logo_url = '' } = site || {};

  return (
    <Head>
      <title>{`${name} | ${pageTitle}`}</title>
      <style type="text/css">
        {`
          :root {
            --theme-color: ${color};
            --logo-url: url(${logo_url});
            --header-color: ${header_color};
          };
        `}
      </style>
    </Head>
  );
};

const mapStateToProps = ({ site }) => ({ site });

export default connect(mapStateToProps)(CustomHead);
