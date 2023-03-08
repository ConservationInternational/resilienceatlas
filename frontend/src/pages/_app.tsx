import React from 'react';
import { Provider } from 'react-redux';

import store from 'state/store';

export default function MyApp({ Component, pageProps }) {
  return (
    <Provider store={store}>
      <Component {...pageProps} />
    </Provider>
  );
}
