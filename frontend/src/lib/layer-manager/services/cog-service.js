import axios, { CancelToken } from 'axios';
import { get } from '../lib/request';
import { getTitilerBaseUrl, getApiBaseUrl } from '../../../utilities/environment';

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

  const sources =
    Array.isArray(layerConfig?.body?.sources) && layerConfig.body.sources.length > 0
      ? layerConfig.body.sources
      : layerConfig?.body?.source
        ? [layerConfig.body.source]
        : [];

  // New format: source URL is stored directly in body.source/body.sources
  if (sources.length > 0) {
    return {
      titilerBaseUrl: getTitilerBaseUrl(),
      cogUrls: sources,
      bidx: layerConfig.body.bidx || null,
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

    return { titilerBaseUrl, cogUrls: [cogUrl] };
  } catch (error) {
    console.error('[COG Service] Error parsing COG layer URLs:', error);
    return null;
  }
};

/**
 * Fetch bounds for a COG layer from TiTiler /info endpoint
 * @param {Object} layerModel - The layer model
 * @returns {Promise<[[number, number], [number, number]] | null>} - Bounds as [[south, west], [north, east]] or null
 */
export const fetchCogBounds = (layerModel) => {
  const urls = parseCogLayerUrls(layerModel);
  if (!urls) {
    return Promise.resolve(null);
  }

  const { titilerBaseUrl, cogUrls } = urls;

  // Use the backend API proxy to avoid CORS issues when calling TiTiler directly
  // The proxy forwards the request to TiTiler's /info endpoint
  const apiBaseUrl = getApiBaseUrl();
  // Cancel any existing bounds request for this layer
  const { cogBoundsRequest } = layerModel;
  if (cogBoundsRequest) {
    cogBoundsRequest.cancel('Operation canceled - new request initiated.');
  }

  const cogBoundsRequestSource = CancelToken.source();
  layerModel.set('cogBoundsRequest', cogBoundsRequestSource);

  const requests = cogUrls.map((cogUrl) => {
    const infoUrl = `${apiBaseUrl}/api/titiler/info?titilerUrl=${encodeURIComponent(titilerBaseUrl)}&cogUrl=${encodeURIComponent(cogUrl)}`;
    return get(infoUrl, { cancelToken: cogBoundsRequestSource.token }).then((res) => {
      if (res.status > 400) {
        console.error('[COG Service] Error fetching COG info:', res);
        return null;
      }

      const data = res.data;
      if (data && data.bounds && Array.isArray(data.bounds) && data.bounds.length === 4) {
        const [minx, miny, maxx, maxy] = data.bounds;
        return [
          [miny, minx],
          [maxy, maxx],
        ];
      }

      console.warn('[COG Service] Bounds not found in TiTiler info response:', data);
      return null;
    });
  });

  return Promise.all(requests)
    .then((boundsList) => {
      const validBounds = boundsList.filter(Boolean);
      if (validBounds.length === 0) return null;

      const south = Math.min(...validBounds.map((bounds) => bounds[0][0]));
      const west = Math.min(...validBounds.map((bounds) => bounds[0][1]));
      const north = Math.max(...validBounds.map((bounds) => bounds[1][0]));
      const east = Math.max(...validBounds.map((bounds) => bounds[1][1]));

      return [
        [south, west],
        [north, east],
      ];
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
