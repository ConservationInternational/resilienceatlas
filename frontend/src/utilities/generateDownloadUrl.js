import { PORT } from '../state/utils/api';
/**
 * Used only from schema.js, receives unprocessed layer to generate download url
 * @param  {object} layer unnormalized layer data
 */
export const generateDownloadUrl = layer =>
  `${PORT}/api/layers/${
    layer.id
  }/downloads?file_format=kml&with_format=true&download_path=https://cdb-cdn.resilienceatlas.org/user/ra/api/v2/sql?filename=${
    layer.attributes.slug
  }&q=${encodeURIComponent(layer.attributes.query)}`;
