import axios, { CancelToken } from 'axios';
import { get } from '../lib/request';
import { replace } from '../utils/query';

// Symbol to indicate a canceled request
export const CANCELED = Symbol('CANCELED');

export const fetchTile = (layerModel) => {
  const { layerConfig, params, sqlParams, interactivity } = layerModel;

  const layerConfigParsed =
    layerConfig.parse === false
      ? layerConfig
      : JSON.parse(replace(JSON.stringify(layerConfig), params, sqlParams));

  const layerTpl = JSON.stringify({
    version: '1.3.0',
    stat_tag: 'API',
    layers: layerConfigParsed.body.layers.map((l) => {
      if (!!interactivity && interactivity.length) {
        return { ...l, options: { ...l.options, interactivity: interactivity.split(', ') } };
      }
      return l;
    }),
  });
  const apiParams = `?stat_tag=API&config=${encodeURIComponent(layerTpl)}`;

  const url = `https://${layerConfigParsed.account}-cdn.resilienceatlas.org/user/ra/api/v1/map${apiParams}`;

  const { layerRequest } = layerModel;
  if (layerRequest) {
    layerRequest.cancel('Operation canceled by the user.');
  }

  const layerRequestSource = CancelToken.source();
  layerModel.set('layerRequest', layerRequestSource);

  const newLayerRequest = get(url, { cancelToken: layerRequestSource.token })
    .then((res) => {
      if (res.status > 400) {
        console.error(res);
        return false;
      }

      return res.data;
    })
    .catch((err) => {
      // Silently handle canceled requests - return CANCELED symbol instead of rejecting
      if (axios.isCancel(err)) {
        return CANCELED;
      }
      throw err;
    });

  return newLayerRequest;
};

export const fetchBounds = (layerModel) => {
  const { layerConfig, params, sqlParams, type } = layerModel;
  let { sql } = layerModel;
  const isRaster = type === 'raster';

  if (isRaster) {
    // For raster layers, extract geometry from the raster envelope
    sql = `SELECT ST_Union(ST_Transform(ST_Envelope(the_raster_webmercator), 4326)) as the_geom FROM (${sql}) as t`;
  }

  const layerConfigParsed =
    layerConfig.parse === false
      ? layerConfig
      : JSON.parse(replace(JSON.stringify(layerConfig), params, sqlParams));

  // For raster layers, we already have the_geom from the wrapper query above
  // For vector layers, use COALESCE to handle both the_geom and the_geom_webmercator columns
  const geomExpr = isRaster
    ? 'the_geom'
    : 'COALESCE(the_geom, ST_Transform(the_geom_webmercator, 4326))';

  const s = `
    SELECT ST_XMin(ST_Extent(${geomExpr})) as minx,
    ST_YMin(ST_Extent(${geomExpr})) as miny,
    ST_XMax(ST_Extent(${geomExpr})) as maxx,
    ST_YMax(ST_Extent(${geomExpr})) as maxy
    from (${sql}) as subq
  `;

  const url = `https://${layerConfigParsed.account}-cdn.resilienceatlas.org/user/ra/api/v2/sql?q=${s.replace(/\n/g, ' ')}`;

  const { boundsRequest } = layerModel;
  if (boundsRequest) {
    boundsRequest.cancel('Operation canceled by the user.');
  }

  const boundsRequestSource = CancelToken.source();
  layerModel.set('boundsRequest', boundsRequestSource);

  const newBoundsRequest = get(url, { cancelToken: boundsRequestSource.token })
    .then((res) => {
      if (res.status > 400) {
        console.error(res);
        return false;
      }

      return res.data;
    })
    .catch((err) => {
      // Silently handle canceled requests - return CANCELED symbol instead of rejecting
      if (axios.isCancel(err)) {
        return CANCELED;
      }
      throw err;
    });

  return newBoundsRequest;
};

export default { fetchTile, fetchBounds };
