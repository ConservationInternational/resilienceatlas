import React from 'react';

import Head from './_head';
import Icons from './_icons';

export default Page => props => (
  <>
    <Head />

    <Icons />

    <div className="l-main--embed">
      <Page {...props} />
    </div>
  </>
);
