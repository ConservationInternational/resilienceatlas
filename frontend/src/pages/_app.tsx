import { Provider as ReduxProvider } from 'react-redux';
import Head from 'next/head';

import { wrapper } from 'state/store';

import type { ReactElement, ReactNode } from 'react';
import type { NextPage } from 'next';
import type { AppProps } from 'next/app';

// CSS
import 'normalize.css/normalize.css';
import 'slick-carousel/slick/slick.css';
import 'slick-carousel/slick/slick-theme.css';
import 'views/styles/index.scss';

type ResilienceAppProps = {
  dispatch?: (action: unknown) => void;
};

export type NextPageWithLayout<P = ResilienceAppProps, IP = P> = NextPage<P, IP> & {
  Layout?: (page: ReactElement) => ReactNode;
};

type AppPropsWithLayout = AppProps & {
  Component: NextPageWithLayout;
};

const ResilienceApp = ({ Component, ...rest }: AppPropsWithLayout) => {
  const { store: appStore } = wrapper.useWrappedStore(rest);
  const getLayout = Component.Layout ?? ((page) => page);

  return (
    <>
      <Head>
        <meta name="theme-color" content="#000000" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta
          content="An interactive tool that provides users with a deep understanding of the resilience of specific systems like livestock or agriculture"
          name="description"
        />
        <meta content="Resilience Atlas" itemProp="name" />
        <meta content="Resilience Atlas" itemProp="description" />
        <meta content="logo.jpg" itemProp="image" />
        <meta content="Resilience Atlas" name="twitter:card" />
        <meta content="@resilienceatlas" name="twitter:site" />
        <meta content="Resilience Atlas" name="twitter:title" />
        <meta
          content="An interactive tool that provides users with a deep understanding of the resilience of specific systems like livestock or agriculture"
          name="twitter:description"
        />
        <meta content="" name="twitter:creator" />
        <meta content="logo.jpg" name="twitter:image:src" />
        <meta content="" name="twitter:player" />
        <meta content="www.resilienceatlas.org" property="og:url" />
        <meta content="Resilience Atlas" property="og:title" />
        <meta
          content="The Resilience Atlas is a breakthrough interactive tool that includes more than 60 datasets in an easy-to-use interface to gauge resilience at local, national, and regional scales."
          property="og:description"
        />
        <meta content="Resilience Atlas" property="og:site_name" />
        <meta content="logo.jpg" property="og:image" />
        <meta content="" property="fb:admins" />
        <meta content="" property="fb:app_id" />
        <meta content="" property="og:type" />
        <meta content="en_US" property="og:locale" />
        <meta content="" property="og:audio" />
        <meta httpEquiv="X-UA-Compatible" content="IE=11; IE=10; IE=9; IE=8; IE=7; IE=EDGE" />

        {/* manifest.json provides metadata used when your web app is installed on a
          user's mobile device or desktop. See https://developers.google.com/web/fundamentals/web-app-manifest/ */}
        <link rel="manifest" href="/manifest.json" />

        {/* Leaflet CDN */}
        <link
          rel="stylesheet"
          href="https://unpkg.com/leaflet@1.4.0/dist/leaflet.css"
          integrity="sha512-puBpdR0798OZvTTbP4A8Ix/l+A4dHDD0DGqYW6RQ+9jxkRFclaxxQb/SJAWZfWAkuyeQUytO7+7N4QKrDh+drA=="
          crossOrigin=""
        />
      </Head>
      <ReduxProvider store={appStore}>{getLayout(<Component {...rest.pageProps} />)}</ReduxProvider>
    </>
  );
};

export default ResilienceApp;
