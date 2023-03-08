import React from 'react';

import Head from './_head';
import Icons from './_icons';

export default (Page) => (props) =>
  (
    <>
      <Head page="report" />

      <Icons />

      <div className="l-main">
        <Page {...props} />
      </div>
    </>
  );
