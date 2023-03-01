import { subdomain } from '@utilities/getSubdomain';
import api, { createApiAction } from '../../utils/api';
import { site_scope } from '../../schema';

const URL_SITE = '/site';

// Action constants
export const LOAD = createApiAction('site/LOAD');

export const load = () =>
  api(LOAD, ({ get }) => get(URL_SITE, { params: { site_scope: subdomain } }), {
    schema: site_scope,
  });
