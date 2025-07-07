import { useEffect, useState } from 'react';
import { Provider as ReduxProvider } from 'react-redux';
import Head from 'next/head';
import { useRouter } from 'next/router';
import { QueryClient, QueryClientProvider, Hydrate } from '@tanstack/react-query';
import { tx, PseudoTranslationPolicy } from '@transifex/native';
import { TourProvider } from '@reactour/tour';
import { CookiesProvider, useCookies } from 'react-cookie';
import { T } from '@transifex/react';

import { wrapper } from 'state/store';
import * as ga from 'utilities/ga';
import { getToken, login } from 'state/modules/user';
import TOUR_STEPS from 'constants/tour-steps';

import { Badge, Navigation } from 'views/components/MapTour';
import SiteScopeAuthModal from 'views/components/SiteScopeAuthModal';

import type { Translations } from 'types/transifex';
import type { ReactElement, ReactNode } from 'react';
import type { NextPage } from 'next';
import type { AppProps } from 'next/app';
import type { DehydratedState } from '@tanstack/react-query';
import type { ProviderProps as MapTourProviderProps } from '@reactour/tour';

// Third-party styles
import 'normalize.css/normalize.css';
import 'slick-carousel/slick/slick.css';
import 'slick-carousel/slick/slick-theme.css';
import 'leaflet/dist/leaflet.css';

// Project styles
import 'views/styles/index.scss';

const { NEXT_PUBLIC_TRANSIFEX_TOKEN } = process.env;
const REACT_TOUR_OPTIONS: Omit<MapTourProviderProps, 'children'> = {
  steps: TOUR_STEPS,
  padding: 4,
  showDots: false,
  className: 'map-tour-popover',
  maskClassName: 'map-tour-mask',
  badgeContent: ({ currentStep, totalSteps }) => (
    <>
      <T _str="Map tour" /> {currentStep + 1}/{totalSteps}
    </>
  ),
  styles: {
    maskWrapper: (base) => ({ ...base, opacity: 0.3 }),
    close: (base) => ({ ...base, color: '#555' }),
  },
  components: {
    Badge,
    Navigation,
  },
  // Disabling interaction on the overlay mask
  onClickMask: () => null,
};

export type ResilienceAppProps = {
  dehydratedState?: DehydratedState;
  translations: Translations;
  setTranslations?: (translations: Translations) => {
    type: string;
    translations: Translations;
  };
  dispatch?: (action: unknown) => void;
  isSidebarOpen?: boolean;
};

export type JourneyPageProps = ResilienceAppProps & {
  published: boolean;
};

export type NextPageWithLayout<P = ResilienceAppProps, IP = P> = NextPage<P, IP> & {
  Layout?: (page: ReactElement, translations: Translations) => ReactNode;
};

export type JourneyNextPageWithLayout<P = JourneyPageProps, IP = P> = NextPage<P, IP> & {
  Layout?: (page: ReactElement, translations: Translations) => ReactNode;
};

type AppPropsWithLayout = AppProps<ResilienceAppProps> & {
  Component: NextPageWithLayout;
};

const ResilienceApp = ({ Component, ...rest }: AppPropsWithLayout) => {
  const router = useRouter();
  const { store: appStore } = wrapper.useWrappedStore(rest);
  const getLayout = Component.Layout ?? ((page) => page);
  const { locale, locales, asPath } = router;
  const [queryClient] = useState(
    () =>
      new QueryClient({
        defaultOptions: {
          queries: {
            refetchOnWindowFocus: false,
          },
        },
      }),
  );

  // Getting user from local storage
  useEffect(() => {
    const token = getToken();

    if (token) {
      appStore.dispatch(login(token));
    }
  }, [appStore]);

  // Google Analytics
  useEffect(() => {
    const handleRouteChange = (url) => {
      ga.pageView(url);
    };
    //When the component is mounted, subscribe to router changes
    //and log those page views
    router.events.on('routeChangeComplete', handleRouteChange);

    // If the component is unmounted, unsubscribe
    // from the event with the `off` method
    return () => {
      router.events.off('routeChangeComplete', handleRouteChange);
    };
  }, [router.events]);

  // Transifex

  useEffect(() => {
    // Only initialize Transifex if a token is provided and not empty
    if (NEXT_PUBLIC_TRANSIFEX_TOKEN && NEXT_PUBLIC_TRANSIFEX_TOKEN.trim() !== '') {
      // Used for initial render
      tx.init({
        token: NEXT_PUBLIC_TRANSIFEX_TOKEN,
        ...(process.env.NODE_ENV === 'development'
          ? { missingPolicy: new PseudoTranslationPolicy() }
          : {}),
      });

      tx.setCurrentLocale(locale);
    } else if (process.env.NODE_ENV === 'development') {
      // In development without token, just log a warning
      // eslint-disable-next-line no-console
      console.warn('Transifex token not provided. Translation service disabled.');
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [router]);

  const [cookies, setCookie] = useCookies(['NEXT_LOCALE']);
  const { NEXT_LOCALE } = cookies;
  // WARN: do not modify without knowing exactly what are the consequences
  // When the user visits any page, Next.js determines the supported locale the user is using:
  // https://nextjs.org/docs/advanced-features/i18n-routing#automatic-locale-detection
  // This locale is the one that can be retrieved through the `useRouter` hook.
  // The client requests don't rely on Next.js `locale` attribute but rather on
  // the `NEXT_LOCALE` cookie since we can't have access to the Next.js hook there. If no cookie is
  // set, then the requests fallbacks to the default locale set in `locales.config.json`.
  // Look at this example:
  // - The user's browser is set in English
  // - The application's default locale is Spanish
  // - This is the user's first visit
  // - If the user goes on a fully static page (such as the Login) all of its content will be
  //   displayed in English (Next.js determines the locale based on the `Accept-Language` header)
  // - If the user goes to a non-static page (such as Journeys), all the content rendered on the
  //   server will be in English, but all the requests made on the client will fetch content in
  //   Spanish since no `NEXT_LOCALE` cookie exists
  // For this reason, we want to always set the cookie on the first given opportunity.
  useEffect(() => {
    if (!NEXT_LOCALE) {
      // Set a cookie for 1 year
      setCookie('NEXT_LOCALE', `${locale}; path=/; max-age=31536000; secure`);
    }
  }, [locale, NEXT_LOCALE, setCookie]);

  ga.useInitGAScript();

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

        {locales.map((locale) => (
          <link
            key={locale}
            rel="alternate"
            hrefLang={locale}
            href={`${process.env.NEXT_PUBLIC_FRONTEND_URL}/${locale}${asPath}`}
          />
        ))}
        <link
          rel="alternate"
          hrefLang="x-default"
          href={`${process.env.NEXT_PUBLIC_FRONTEND_URL}${asPath}`}
        />
      </Head>
      <ReduxProvider store={appStore} key="redux-provider">
        <QueryClientProvider client={queryClient}>
          <CookiesProvider>
            <TourProvider {...REACT_TOUR_OPTIONS}>
              <Hydrate state={rest.pageProps.dehydratedState}>
                {getLayout(<Component {...rest.pageProps} />, rest.pageProps?.translations)}
                <SiteScopeAuthModal />
              </Hydrate>
            </TourProvider>
          </CookiesProvider>
        </QueryClientProvider>
      </ReduxProvider>
    </>
  );
};

export default ResilienceApp;
