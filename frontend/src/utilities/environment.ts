/**
 * Environment utility functions
 */

/**
 * Check if the application is running in development mode
 * @returns {boolean} true if NODE_ENV is 'development'
 */
export const isDevelopment = (): boolean => {
  return process.env.NODE_ENV === 'development';
};

/**
 * Check if the application is running in production mode
 * @returns {boolean} true if NODE_ENV is 'production'
 */
export const isProduction = (): boolean => {
  return process.env.NODE_ENV === 'production';
};

/**
 * Check if the application is running in test mode
 * @returns {boolean} true if NODE_ENV is 'test'
 */
export const isTest = (): boolean => {
  return process.env.NODE_ENV === 'test';
};