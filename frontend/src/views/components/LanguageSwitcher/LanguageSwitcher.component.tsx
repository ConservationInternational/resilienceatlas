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

// TODO: Set ts type for languages

function LanguageSwitcher() {
  const languages = useLanguages();
  const { setParam } = useRouterParams();
  const changeLang = (code: (typeof AVAILABLE_LANGUAGES)[number]) => {
    setParam('lang', code);
  };

  const mockAvailableLanguages = AVAILABLE_LANGUAGES.map((l) => ({
    code: l,
  }));
  const availableLanguages = useMemo(
    () => languages.filter((l) => AVAILABLE_LANGUAGES.includes(l.code)),
    [languages],
  );
  const locale = useLocale();
  const _availablelanguages = mockAvailableLanguages || availableLanguages;
  const renderLanguageSwitcher = () =>
    _availablelanguages.map(({ code }, index) => (
      <li key={code} className="-childless">
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
                console.warn(
                  'TODO: Transifex is not initialized. Are the env variables set up?',
                  error,
                );
                changeLang(code);
              });
          }}
        >
          {code}
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
