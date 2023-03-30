/* eslint-disable @next/next/no-img-element */
import React, { useMemo } from 'react';

import { tx } from '@transifex/native';
import { useLanguages, useLocale } from '@transifex/react';
import { useRouterParams } from 'utilities';
import cx from 'classnames';

const AVAILABLE_LANGUAGES = ['en', 'fr', 'es', 'zh', 'pt', 'ru'];

// Don't translate these
const LANGUAGE_LABELS = {
  zh: '中文',
  en: 'English',
  fr: 'Français',
  pt: 'Português',
  ru: 'Русский',
  es: 'Castellano',
};

type Language = {
  code: string;
  localized_name: string;
  name: string;
  rtl: boolean;
};

function LanguageSwitcher() {
  const languages: Language[] = useLanguages();
  const { setParam } = useRouterParams();
  const changeLang = (code: (typeof AVAILABLE_LANGUAGES)[number]) => {
    setParam('lang', code);
  };

  const mockAvailableLanguages = AVAILABLE_LANGUAGES.map((l) => ({
    code: l,
  }));
  const availableLanguages = useMemo<Language[]>(
    () => languages.filter((l) => AVAILABLE_LANGUAGES.includes(l.code)),
    [languages],
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
