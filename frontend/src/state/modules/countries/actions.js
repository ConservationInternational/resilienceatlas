import api, { createApiAction } from '../../utils/api';
import { country } from '../../schema';

const URL = '/admin-boundaries';

export const LOAD = createApiAction('countries/LOAD');
export const LOAD_GEOMETRY = createApiAction('countries/LOAD_GEOMETRY');

// Loads the country list without geometry — fast, lightweight response.
// Geometry is fetched on demand via loadGeometry(iso) when a country is selected.
export const load = () =>
  api(
    LOAD,
    ({ get }) =>
      get(URL, { params: { admin_level: 0, geometry: false } }).then((response) => {
        const boundaries = response.data?.data || [];
        const rows = boundaries
          .filter((b) => b.name && b.iso_code)
          .map((b) => ({
            name: b.name,
            iso: b.iso_code,
          }));
        return { ...response, data: { rows } };
      }),
    { schema: { rows: [country] } },
  );

// Fetches the GeoJSON geometry for a single country by ISO code, on demand.
export const loadGeometry = (iso) =>
  api(LOAD_GEOMETRY, ({ get }) =>
    get(`${URL}/${iso}`).then((response) => {
      const boundary = response.data?.data;
      return {
        ...response,
        data: {
          iso,
          geometry: boundary?.geometry || null,
        },
      };
    }),
  );
