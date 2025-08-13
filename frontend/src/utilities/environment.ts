/**
 * Environment configuration utilities
 * Helps determine deployment environment and configure app behavior accordingly
 */

/**
 * Get the current deployment environment
 */
export const getDeploymentEnvironment = (): 'development' | 'staging' | 'production' => {
  if (process.env.NODE_ENV === 'development') {
    return 'development';
  }

  // Check if we're on staging based on API host
  const apiHost = process.env.NEXT_PUBLIC_API_HOST;
  if (apiHost && apiHost.includes('staging')) {
    return 'staging';
  }

  // Check if we're on staging based on current hostname (client-side)
  if (typeof window !== 'undefined') {
    if (window.location.hostname.includes('staging.resilienceatlas.org')) {
      return 'staging';
    }
  }

  return 'production';
};

/**
 * Check if we're running in development
 */
export const isDevelopment = (): boolean => {
  return getDeploymentEnvironment() === 'development';
};

/**
 * Check if we're running on staging
 */
export const isStaging = (): boolean => {
  return getDeploymentEnvironment() === 'staging';
};

/**
 * Check if we're running in production
 */
export const isProduction = (): boolean => {
  return getDeploymentEnvironment() === 'production';
};

/**
 * Get the base domain for the current environment
 */
export const getBaseDomain = (): string => {
  const env = getDeploymentEnvironment();

  switch (env) {
    case 'staging':
      return 'staging.resilienceatlas.org';
    case 'production':
      return 'resilienceatlas.org';
    case 'development':
    default:
      return 'localhost:3000';
  }
};

/**
 * Get the API base URL for the current environment
 */
export const getApiBaseUrl = (): string => {
  return process.env.NEXT_PUBLIC_API_HOST || 'http://localhost:3001';
};

/**
 * Check if the current hostname supports subdomains
 */
export const supportsSubdomains = (): boolean => {
  if (isDevelopment()) {
    // In development, subdomains work but we can use query params for testing
    return true;
  }

  // Both staging and production support subdomains
  return isStaging() || isProduction();
};