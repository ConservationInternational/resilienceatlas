import { toBackendLocale } from 'utilities/helpers';
import api, { createApiAction } from '../../utils/api';

const URL_ABOUT = '/static_pages/about';

export const LOAD = createApiAction('about/LOAD');

export const load = (locale) =>
  api(LOAD, ({ get }) => get(URL_ABOUT, { params: { locale: toBackendLocale(locale) } }), {
    locale,
  });
