import React from 'react';

import Head from './_head';
import Header from './_header';
import Icons from './_icons';

export default Page => props => (
  <>
    <Head />

    <Icons />

    <Header />

    <div className="l-main--fullscreen">
      <Page {...props} />
    </div>
  </>
);
