import { subdomain } from 'utilities/getSubdomain';
import api, { createApiAction } from '../../utils/api';
import { layer_group } from '../../schema';
import { toBackendLocale } from 'utilities/helpers';

const URL_LAYER_GROUPS = '/layer-groups';

// Action constants
export const LOAD = createApiAction('layer_groups/LOAD');
export const TOGGLE = 'layer_groups / TOGGLE';
export const OPEN_BATCH = 'layer_groups / OPEN_BATCH';

// Actions
export const toggle = (id) => ({
  type: TOGGLE,
  id,
});

export const openBatch = (ids = []) => ({
  type: OPEN_BATCH,
  ids,
});

export const load = (locale, siteScope) =>
  api(
    LOAD,
    ({ get }) =>
      get(URL_LAYER_GROUPS, {
        params: { site_scope: siteScope || subdomain, locale: toBackendLocale(locale) },
      }),
    {
      schema: [layer_group],
      locale,
      subdomain: siteScope || subdomain,
    },
  );
