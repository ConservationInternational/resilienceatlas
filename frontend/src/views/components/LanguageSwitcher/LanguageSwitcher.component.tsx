/* eslint-disable @next/next/no-img-element */
import React, { useCallback, useMemo } from 'react';
import localesJson from 'locales.config.json';
import cx from 'classnames';
import { setCookie } from 'utilities/helpers';
import { useRouter } from 'next/router';

const LANGUAGE_LABELS = localesJson.locales.reduce((acc, locale) => {
  acc[locale.locale] = locale.name;
  return acc;
}, {});

function LanguageSwitcher() {
  const router = useRouter();

  const changeLang = useCallback(
    (locale: string) => {
      // Set a cookie for 1 year so that the user preference is kept
      setCookie('NEXT_LOCALE', `${locale}; path=/; max-age=31536000; secure`);

      const { pathname, asPath, query } = router;
      // change just the locale and maintain all other route information including href's query
      router.push({ pathname, query }, asPath, { locale });
    },
    [router],
  );

  const { locales, locale } = router;

  const availableLanguages = useMemo(
    () =>
      locales.map((l) => ({
        code: l,
      })),
    [locales],
  );

  const renderLanguageSwitcher = () =>
    availableLanguages.map(({ code }, index) => (
      <li key={code} className="language-item -childless">
        <button
          type="button"
          className={cx(
            'language-button',
            locale === code && 'selected',
            index !== availableLanguages.length - 1 && 'separator',
          )}
          onClick={() => {
            changeLang(code);
          }}
        >
          {LANGUAGE_LABELS[code]}
        </button>
      </li>
    ));

  return (
    <li className="language-switcher">
      <span className="item-separator" />
      <img src="/images/svg-icons/language.svg" alt="language-icon" />
      <div className="nav-item">{LANGUAGE_LABELS[locale]}</div>
      <ul>{renderLanguageSwitcher()}</ul>
    </li>
  );
}

export default LanguageSwitcher;
