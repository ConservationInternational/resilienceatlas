import api, { createApiAction } from '../../utils/api';
import { site_scope } from '../../schema';

const URL_SITE = '/sites';

// Action constants
export const LOAD = createApiAction('sites/LOAD');

export const load = () =>
  api(LOAD, ({ get }) => get(URL_SITE), { schema: [site_scope] });
