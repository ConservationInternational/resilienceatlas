import { fetchCogBounds, CANCELED } from '../../services/cog-service';
import { replace } from '../../utils/query';
import { getTitilerBaseUrl } from '../../../../utilities/environment';

// Get L dynamically at runtime, not at module load time
const getL = () => (typeof window !== 'undefined' ? window.L : undefined);

/**
 * Build the TiTiler tile URL from layer config
 * @param {Object} layerConfig - The layer configuration
 * @returns {string} - The complete TiTiler tile URL
 */
const buildTitilerUrl = (layerConfig) => {
  const { body } = layerConfig;

  // If the config already has a URL (legacy format), use it directly
  if (body.url) {
    return body.url;
  }

  // New format: construct URL from source and colormap
  const { source, colormap } = body;

  if (!source) {
    console.error('[COG Layer] No source URL found in layerConfig.body');
    return null;
  }

  // Get the TiTiler base URL for the current environment
  const titilerBaseUrl = getTitilerBaseUrl();

  // Encode the COG source URL
  const encodedSource = encodeURIComponent(source);

  // Build the tile URL
  let tileUrl = `${titilerBaseUrl}/tiles/WebMercatorQuad/{z}/{x}/{y}?url=${encodedSource}`;

  // Add colormap if present
  if (colormap && Object.keys(colormap).length > 0) {
    const encodedColormap = encodeURIComponent(JSON.stringify(colormap));
    tileUrl += `&colormap=${encodedColormap}`;
  }

  return tileUrl;
};

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
    const { type = 'tileLayer', options = {} } = body;

    // Build the tile URL (handles both legacy and new format)
    const url = buildTitilerUrl(layerConfigParsed);

    if (!url) {
      console.error('[COG Layer] Failed to build tile URL for layer');
      resolve(null);
      return;
    }

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
