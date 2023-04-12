/* eslint-disable @next/next/no-img-element */
import React, { useMemo } from 'react';
import localesJson from 'locales.config.json';
import { tx } from '@transifex/native';
import { useLanguages, useLocale } from '@transifex/react';
import cx from 'classnames';
import { setCookie } from 'utilities/helpers';

import { useRouter } from 'next/router';

const LANGUAGE_LABELS = localesJson.locales.reduce((acc, locale) => {
  acc[locale.locale] = locale.name;
  return acc;
}, {});

type Language = {
  code: string;
  localized_name: string;
  name: string;
  rtl: boolean;
};

function LanguageSwitcher() {
  const languages: Language[] = useLanguages();
  const router = useRouter();

  const setLanguage = (locale) => {
    const { pathname, asPath, query } = router;
    // change just the locale and maintain all other route information including href's query
    router.push({ pathname, query }, asPath, { locale });
  };
  const { locales } = router;
  const changeLang = (locale: (typeof locales)[number]) => {
    setLanguage(locale);

    // Set a cookie for 1 year so that the user preference is kept
    setCookie('NEXT_LOCALE', `${locale}; path=/; max-age=31536000; secure`);
  };

  // This works until we load the languages from transifex or if we don't have them configured
  const mockAvailableLanguages = locales.map((l) => ({
    code: l,
  }));

  const availableLanguages = useMemo<Language[]>(
    () => languages.filter((l) => locales.includes(l.code)),
    [languages, locales],
  );

  const locale = useLocale();
  const _availablelanguages = mockAvailableLanguages || availableLanguages;
  const renderLanguageSwitcher = () =>
    _availablelanguages.map(({ code }, index) => (
      <li key={code} className="language-item -childless">
        <button
          type="button"
          className={cx(
            'language-button',
            (locale.length >= 2 ? locale : 'en') === code && 'selected',
            index !== _availablelanguages.length - 1 && 'separator',
          )}
          onClick={() => {
            // We need to wait until the locale is loaded to avoid race conditions

            tx.setCurrentLocale(code)
              .then(() => {
                changeLang(code);
              })
              .catch((error) => {
                // eslint-disable-next-line no-console
                console.error(
                  'TODO: Transifex is not initialized. Are the env variables set up?',
                  error,
                );
              });
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
      <div className="nav-item">{LANGUAGE_LABELS[locale || 'en']}</div>
      <ul>{renderLanguageSwitcher()}</ul>
    </li>
  );
}

export default LanguageSwitcher;
