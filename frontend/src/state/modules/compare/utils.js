import { getRouterParam } from 'utilities';

/**
 * Parse compare state from URL query parameter
 * URL format: ?compare={"enabled":true,"left":123,"right":456,"pos":50}
 */
export const getCompareStateFromURL = () => {
  try {
    const compareParam = getRouterParam('compare', JSON.parse);
    if (!compareParam) return {};

    return {
      enabled: compareParam.enabled || false,
      leftLayerId: compareParam.left || null,
      rightLayerId: compareParam.right || null,
      sliderPosition: compareParam.pos || 50,
    };
  } catch (e) {
    console.warn('Failed to parse compare state from URL:', e);
    return {};
  }
};

// Note: URL serialization is now handled by getCompareURLState selector in selectors.js
// to keep the serialization logic close to the Redux state and avoid duplication
