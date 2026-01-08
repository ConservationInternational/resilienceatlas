import { toBackendLocale } from 'utilities/helpers';
import api, { createApiAction } from '../../utils/api';

const URL_HOMEPAGE = '/homepage';

export const LOAD = createApiAction('homepage/LOAD');

export const load = (locale) =>
  api(LOAD, ({ get }) => get(URL_HOMEPAGE, { params: { locale: toBackendLocale(locale) } }), {
    locale,
  });
