import { fetchCogBounds, CANCELED } from '../../services/cog-service';
import { replace } from '../../utils/query';

// Get L dynamically at runtime, not at module load time
const getL = () => (typeof window !== 'undefined' ? window.L : undefined);

/**
 * COG Layer handler for Leaflet
 * Handles Cloud Optimized GeoTIFF layers served via TiTiler
 */
const CogLayer = (layerModel) => {
  const L = getL();
  if (!L) throw new Error('Leaflet must be defined.');

  const { layerConfig, params, sqlParams } = layerModel;

  // For COG layers, parse=false is set in schema.js, so no replacement needed for the config
  // The URL has already been processed with colormap encoding
  const layerConfigParsed =
    layerConfig.parse === false
      ? layerConfig
      : JSON.parse(replace(JSON.stringify(layerConfig), params, sqlParams));

  return new Promise((resolve) => {
    const { body } = layerConfigParsed;
    const { url, type = 'tileLayer', options = {} } = body;

    const layer = L[type](url, options);

    resolve(layer);
  });
};

/**
 * Get bounds for a COG layer from TiTiler /info endpoint
 * @param {Object} layerModel - The layer model
 * @returns {Promise<[[number, number], [number, number]] | null>} - Leaflet bounds or null
 */
CogLayer.getBounds = (layerModel) => {
  const L = getL();
  if (!L) throw new Error('Leaflet must be defined.');

  return fetchCogBounds(layerModel)
    .then((bounds) => {
      // Handle canceled requests
      if (bounds === CANCELED) {
        return null;
      }
      return bounds;
    })
    .catch((error) => {
      console.warn('[COG Layer] Failed to fetch bounds:', error);
      return null;
    });
};

export default CogLayer;
