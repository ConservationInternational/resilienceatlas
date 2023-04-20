import { subdomain } from 'utilities/getSubdomain';
import api, { createApiAction } from '../../utils/api';
import { toBackendLocale } from 'utilities/helpers';
import { site_scope } from '../../schema';

const URL_SITE = '/site';

// Action constants
export const LOAD = createApiAction('site/LOAD');

export const load = (locale) =>
  api(
    LOAD,
    ({ get }) =>
      get(URL_SITE, { params: { site_scope: subdomain, locale: toBackendLocale(locale) } }),
    {
      schema: site_scope,
    },
  );
