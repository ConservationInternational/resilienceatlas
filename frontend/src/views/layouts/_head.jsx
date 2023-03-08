import React from 'react';
import Helmet from 'react-helmet';
import cx from 'classnames';
import { connect } from 'react-redux';

// Temporary
const bare = false;

const DEFAULT_TITLE = 'Resilience Atlas';

const Head = ({ site: { name, color, subdomain, header_theme, header_color, logo_url }, page }) => (
  <Helmet
    defaultTitle={DEFAULT_TITLE}
    titleTemplate={`${name}${name === DEFAULT_TITLE ? ' | %s' : ''}`}
  >
    <style type="text/css">{`
      :root {
        --theme-color: ${color};
        --logo-url: url(${logo_url});
        --header-color: ${header_color};
      };
    `}</style>
    <body
      className={cx(
        `is-${subdomain}`,
        `is-${header_theme}`,
        `is-${bare ? '' : 'not-'}bare`,
        `${subdomain === 'atlas' ? 'has' : 'no'}-sidebar-logo`,
        { 'is-indicators': !!subdomain, [`is-${page}-page`]: page },
      )}
    />
  </Helmet>
);

export default connect(({ site }) => ({ site }))(Head);
