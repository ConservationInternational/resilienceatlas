import { tx, normalizeLocale, PseudoTranslationPolicy } from '@transifex/native';

const TRANSLATIONS_TTL_SEC = 60 * 60; // 1hour
const { NEXT_PUBLIC_TRANSIFEX_TOKEN } = process.env;

/**
 * Used by SSR to pass translations to browser
 *
 * @param {*} { locale, locales }
 * @return {*} { locale, locales, translations }
 */
export async function getServerSideTranslations({ locale, locales }) {
  // ensure that nextjs locale is in the Transifex format,
  // for example, de-de -> de_DE
  const txLocale = normalizeLocale(locale);

  tx.init({
    token: NEXT_PUBLIC_TRANSIFEX_TOKEN,
    ...(process.env.NODE_ENV === 'development'
      ? { missingPolicy: new PseudoTranslationPolicy() }
      : {}),
  });

  // load translations over-the-air
  await tx.fetchTranslations(txLocale);

  // bind a helper object in the Native instance for auto-refresh
  tx._autorefresh = tx._autorefresh || {};
  if (!tx._autorefresh[txLocale]) {
    tx._autorefresh[txLocale] = Date.now();
  }

  // check for stale content in the background
  if (Date.now() - tx._autorefresh[txLocale] > TRANSLATIONS_TTL_SEC * 1000) {
    tx._autorefresh[txLocale] = Date.now();
    tx.fetchTranslations(txLocale, { refresh: true });
  }

  return {
    locale,
    locales,
    translations: tx.cache.getTranslations(txLocale),
  };
}
