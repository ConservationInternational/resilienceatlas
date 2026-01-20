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
 * Uses INTERNAL_API_HOST for server-side rendering in Docker
 */
export const getApiBaseUrl = (): string => {
  // On the server, use internal API host if available (for Docker networking)
  if (typeof window === 'undefined' && process.env.INTERNAL_API_HOST) {
    return process.env.INTERNAL_API_HOST;
  }
  // On the client (browser), use the public API host
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

/**
 * Get the TiTiler base URL for the current environment
 * TiTiler domains follow the pattern:
 * - Production (main branch): titiler.resilienceatlas.org
 * - Staging/feature branches: {branch}.titiler.resilienceatlas.org (e.g., staging.titiler.resilienceatlas.org)
 *
 * Can be overridden with NEXT_PUBLIC_TITILER_URL environment variable for custom deployments
 */
export const getTitilerBaseUrl = (): string => {
  // Allow override via environment variable for custom deployments
  if (process.env.NEXT_PUBLIC_TITILER_URL) {
    return process.env.NEXT_PUBLIC_TITILER_URL;
  }

  const env = getDeploymentEnvironment();

  switch (env) {
    case 'staging':
      return 'https://staging.titiler.resilienceatlas.org';
    case 'production':
      return 'https://titiler.resilienceatlas.org';
    case 'development':
    default:
      // In development, default to staging TiTiler
      return 'https://staging.titiler.resilienceatlas.org';
  }
};
