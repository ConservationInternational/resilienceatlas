/* eslint-disable @next/next/no-img-element */
import React, { useCallback, useMemo } from 'react';
import localesJson from 'locales.config.json';
import cx from 'classnames';
import { useRouter } from 'next/router';
import { useCookies } from 'react-cookie';
import { tx } from '@transifex/native';

const LANGUAGE_LABELS = localesJson.locales.reduce((acc, locale) => {
  acc[locale.locale] = locale.name;
  return acc;
}, {});

function LanguageSwitcher({ translations }) {
  const router = useRouter();
  const [, setCookie] = useCookies(['NEXT_LOCALE']);
  const changeLang = useCallback(
    (locale: string) => {
      // Set a cookie for 1 year so that the user preference is kept
      setCookie('NEXT_LOCALE', `${locale}; path=/; max-age=31536000; secure`);

      // We need to change the transifex locale first to avoid transifex native library race conditions
      tx.setCurrentLocale(locale).then(() => {
        const { pathname, asPath, query } = router;
        // change just the locale and maintain all other route information including href's query
        router.push({ pathname, query }, asPath, { locale });
      });
    },
    [router, setCookie],
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
      <img
        src="/images/svg-icons/language.svg"
        alt={translations && translations['language-icon']}
      />
      <div className="nav-item">{LANGUAGE_LABELS[locale]}</div>
      <ul>{renderLanguageSwitcher()}</ul>
    </li>
  );
}

export default LanguageSwitcher;
