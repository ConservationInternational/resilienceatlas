import cx from 'classnames';
import { useMemo, useCallback } from 'react';
import { useAxios } from './useAxios';

const sqlApi = 'https://cdb-cdn.resilienceatlas.org/user/ra/api/v2/sql';

export const useWidget = ({ slug, geojson }, { type, analysisQuery, analysisBody }) => {
  const query = useMemo(() => {
    if (analysisBody) {
      const { assetId } = JSON.parse(analysisBody);
      let parsedQuery = analysisQuery;

      if (type === 'cog') {
        const parsedBody = JSON.parse(analysisBody);
        const { params } = parsedBody || {};
        Object.entries(params).forEach(([key, value]) => {
          parsedQuery = parsedQuery.replace(`{{${key}}}`, value);
        });
      }

      return {
        method: 'post',
        url: parsedQuery,
        data: {
          assetId,
          ...(type === 'cog'
            ? { ...L.geoJSON(geojson).toGeoJSON() }
            : { geometry: L.geoJSON(geojson).toGeoJSON() }),
        },
      };
    }

    const geometry = geojson.features ? geojson.features[0].geometry : geojson.geometry || geojson;

    const q = analysisQuery.replace(/{{geometry}}/g, JSON.stringify(geometry));

    return {
      method: 'get',
      url: sqlApi,
      params: {
        q,
      },
    };
  }, [analysisBody, geojson, analysisQuery, type]);

  const [data, loading, loaded] = useAxios(query, [query]);

  const rootWidgetProps = useCallback(
    () => ({
      id: `widget-${slug.replace(' ', '-')}`,
      className: cx('m-widget', {
        'is-loading': loading,
        loaded,
      }),
    }),
    [loading, loaded, slug],
  );

  const noData = !data || !data.rows || !data.rows.length;

  return {
    rootWidgetProps,
    loaded,
    loading,
    data,
    noData,
  };
};
