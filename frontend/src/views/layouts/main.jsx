import React from 'react';

import Head from './_head';
import Header from './_header';
import Footer from './_footer';

export default (Page) => (props) =>
  (
    <>
      <Head />

      <Header />

      <div className="l-main-fullscreen">
        <Page {...props} />
      </div>

      <Footer />
    </>
  );
