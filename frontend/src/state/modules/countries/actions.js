import api, { createApiAction } from '../../utils/api';
import { country } from '../../schema';

const URL = '/admin-boundaries';

export const LOAD = createApiAction('countries/LOAD');

export const load = () =>
  api(
    LOAD,
    ({ get }) =>
      get(URL, { params: { admin_level: 0 } }).then((response) => {
        const boundaries = response.data?.data || [];
        const rows = boundaries
          .filter((b) => b.name && b.iso_code)
          .map((b) => ({
          name: b.name,
          iso: b.iso_code,
          geometry: b.geometry,
        }));
        return { ...response, data: { rows } };
      }),
    { schema: { rows: [country] } },
  );
