import api, { createApiAction } from '../../utils/api';
import { journey } from '../../schema';
import { toBackendLocale } from 'utilities/helpers';

// Action constants
export const LOAD = createApiAction('journeys/LOAD');
export const LOAD_ONE = createApiAction('journeys/LOAD_ONE');

const URL_JOURNEYS = '/journeys';

export const load = (locale) =>
  api(LOAD, ({ get }) => get(URL_JOURNEYS, { params: { locale: toBackendLocale(locale) } }), {
    schema: [journey],
    locale,
  });

export const loadOne = (id, locale) =>
  api(
    LOAD_ONE,
    ({ get }) => get(`${URL_JOURNEYS}/${id}`, { params: { locale: toBackendLocale(locale) } }),
    { id, locale },
  );
