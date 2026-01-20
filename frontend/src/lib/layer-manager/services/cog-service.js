import axios, { CancelToken } from 'axios';
import { get } from '../lib/request';
import { getTitilerBaseUrl } from '../../../utilities/environment';

// Symbol to indicate a canceled request
export const CANCELED = Symbol('CANCELED');

/**
 * Extract the TiTiler base URL and COG URL from the layer's config
 * Supports both legacy format (url in body) and new format (source in body)
 * @param {Object} layerModel - The layer model containing layerConfig
 * @returns {{ titilerBaseUrl: string, cogUrl: string } | null} - Parsed URLs or null if invalid
 */
const parseCogLayerUrls = (layerModel) => {
  const { layerConfig } = layerModel;

  // New format: source URL is stored directly in body.source
  if (layerConfig?.body?.source) {
    return {
      titilerBaseUrl: getTitilerBaseUrl(),
      cogUrl: layerConfig.body.source,
    };
  }

  // Legacy format: parse the full TiTiler tile URL from body.url
  const tileUrl = layerConfig?.body?.url;
  if (!tileUrl) {
    console.warn('[COG Service] No tile URL or source found in layerConfig.body');
    return null;
  }

  // Parse the TiTiler tile URL to extract:
  // 1. The TiTiler base URL (e.g., https://titiler.resilienceatlas.org)
  // 2. The COG URL from the 'url' query parameter
  //
  // Example tile URL:
  // https://titiler.resilienceatlas.org/tiles/WebMercatorQuad/{z}/{x}/{y}?url=https://storage.googleapis.com/bucket/layer.tif&bidx=1
  try {
    // Use a regex to extract the base URL (before /tiles/)
    const baseUrlMatch = tileUrl.match(/^(https?:\/\/[^/]+)/);
    if (!baseUrlMatch) {
      console.warn('[COG Service] Could not extract base URL from tile URL:', tileUrl);
      return null;
    }
    const titilerBaseUrl = baseUrlMatch[1];

    // Extract the COG URL from the 'url' query parameter
    // The URL might have placeholders like {z}, {x}, {y} so we need to handle that
    const urlParamMatch = tileUrl.match(/[?&]url=([^&]+)/);
    if (!urlParamMatch) {
      console.warn('[COG Service] Could not extract COG URL from tile URL:', tileUrl);
      return null;
    }

    // Decode the URL parameter
    const cogUrl = decodeURIComponent(urlParamMatch[1]);

    return { titilerBaseUrl, cogUrl };
  } catch (error) {
    console.error('[COG Service] Error parsing COG layer URLs:', error);
    return null;
  }
};

/**
 * Fetch bounds for a COG layer from TiTiler /info endpoint
 * @param {Object} layerModel - The layer model
 * @returns {Promise<[[number, number], [number, number]] | null>} - Leaflet bounds or null
 */
export const fetchCogBounds = (layerModel) => {
  const urls = parseCogLayerUrls(layerModel);
  if (!urls) {
    return Promise.resolve(null);
  }

  const { titilerBaseUrl, cogUrl } = urls;

  // Use the Next.js API proxy to avoid CORS issues when calling TiTiler directly
  // The proxy forwards the request to TiTiler's /info endpoint
  const infoUrl = `/api/titiler/info?titilerUrl=${encodeURIComponent(titilerBaseUrl)}&cogUrl=${encodeURIComponent(cogUrl)}`;

  // Cancel any existing bounds request for this layer
  const { cogBoundsRequest } = layerModel;
  if (cogBoundsRequest) {
    cogBoundsRequest.cancel('Operation canceled - new request initiated.');
  }

  const cogBoundsRequestSource = CancelToken.source();
  layerModel.set('cogBoundsRequest', cogBoundsRequestSource);

  return get(infoUrl, { cancelToken: cogBoundsRequestSource.token })
    .then((res) => {
      if (res.status > 400) {
        console.error('[COG Service] Error fetching COG info:', res);
        return null;
      }

      const data = res.data;

      // TiTiler /info response includes bounds as [minx, miny, maxx, maxy]
      // in geographic coordinates (EPSG:4326)
      if (data && data.bounds && Array.isArray(data.bounds) && data.bounds.length === 4) {
        const [minx, miny, maxx, maxy] = data.bounds;

        // Convert to Leaflet bounds format: [[south, west], [north, east]]
        // which is [[miny, minx], [maxy, maxx]] in lat/lng order
        const leafletBounds = [
          [miny, minx],
          [maxy, maxx],
        ];

        return leafletBounds;
      }

      console.warn('[COG Service] Bounds not found in TiTiler info response:', data);
      return null;
    })
    .catch((err) => {
      // Handle canceled requests silently
      if (axios.isCancel(err)) {
        return CANCELED;
      }
      console.error('[COG Service] Error fetching COG bounds:', err);
      throw err;
    });
};
