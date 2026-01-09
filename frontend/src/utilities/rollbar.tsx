'use client';

import { Component, createContext, useContext, useEffect, useRef, ReactNode } from 'react';
import Rollbar from 'rollbar';

// Rate limiting configuration to prevent Rollbar spam
interface RateLimitEntry {
  count: number;
  firstSeen: number;
  lastSeen: number;
  suppressed: number;
}

interface RateLimiterConfig {
  windowMs: number; // Time window in milliseconds
  maxPerWindow: number; // Max errors of same type per window
  cleanupIntervalMs: number; // How often to clean up old entries
}

const DEFAULT_RATE_LIMIT_CONFIG: RateLimiterConfig = {
  windowMs: 60000, // 1 minute window
  maxPerWindow: 5, // Max 5 of same error per minute
  cleanupIntervalMs: 300000, // Cleanup every 5 minutes
};

// Rate limiter class for tracking and limiting error reports
class RollbarRateLimiter {
  private errorCounts: Map<string, RateLimitEntry> = new Map();
  private config: RateLimiterConfig;
  private lastCleanup: number = Date.now();

  constructor(config: Partial<RateLimiterConfig> = {}) {
    this.config = { ...DEFAULT_RATE_LIMIT_CONFIG, ...config };
  }

  // Generate a key for the error to track similar errors together
  private getErrorKey(error: Error | string, extra?: Record<string, unknown>): string {
    if (typeof error === 'string') {
      return `str:${error}`;
    }
    // For Error objects, use name + message + first line of stack
    const stackFirstLine = error.stack?.split('\n')[1]?.trim() || '';
    return `err:${error.name}:${error.message}:${stackFirstLine}`;
  }

  // Check if an error should be rate limited
  shouldLimit(error: Error | string, extra?: Record<string, unknown>): boolean {
    this.maybeCleanup();

    const key = this.getErrorKey(error, extra);
    const now = Date.now();
    const entry = this.errorCounts.get(key);

    if (!entry) {
      // First occurrence, create entry
      this.errorCounts.set(key, {
        count: 1,
        firstSeen: now,
        lastSeen: now,
        suppressed: 0,
      });
      return false;
    }

    // Check if we're still within the rate limit window
    if (now - entry.firstSeen < this.config.windowMs) {
      if (entry.count >= this.config.maxPerWindow) {
        // Rate limited - increment suppressed count
        entry.suppressed++;
        entry.lastSeen = now;
        return true;
      }
      // Within window but under limit
      entry.count++;
      entry.lastSeen = now;
      return false;
    }

    // Window has expired, reset the entry
    this.errorCounts.set(key, {
      count: 1,
      firstSeen: now,
      lastSeen: now,
      suppressed: 0,
    });
    return false;
  }

  // Get suppressed count for an error (useful for summary reports)
  getSuppressedCount(error: Error | string, extra?: Record<string, unknown>): number {
    const key = this.getErrorKey(error, extra);
    return this.errorCounts.get(key)?.suppressed || 0;
  }

  // Periodic cleanup of old entries
  private maybeCleanup(): void {
    const now = Date.now();
    if (now - this.lastCleanup < this.config.cleanupIntervalMs) {
      return;
    }

    this.lastCleanup = now;
    const cutoff = now - this.config.windowMs * 2;

    for (const [key, entry] of this.errorCounts.entries()) {
      if (entry.lastSeen < cutoff) {
        // If there were suppressed errors, we could log a summary here
        this.errorCounts.delete(key);
      }
    }
  }

  // Get stats for debugging/monitoring
  getStats(): { trackedErrors: number; totalSuppressed: number } {
    let totalSuppressed = 0;
    for (const entry of this.errorCounts.values()) {
      totalSuppressed += entry.suppressed;
    }
    return {
      trackedErrors: this.errorCounts.size,
      totalSuppressed,
    };
  }
}

// Create singleton rate limiter
const rateLimiter = new RollbarRateLimiter();

// Rollbar configuration
const getRollbarConfig = (): Rollbar.Configuration => ({
  accessToken: process.env.NEXT_PUBLIC_ROLLBAR_CLIENT_TOKEN || '',
  environment: process.env.NODE_ENV === 'production' ? 'production' : 'development',
  captureUncaught: true,
  captureUnhandledRejections: true,
  enabled: Boolean(process.env.NEXT_PUBLIC_ROLLBAR_CLIENT_TOKEN),
  payload: {
    client: {
      javascript: {
        source_map_enabled: true,
        code_version: process.env.NEXT_PUBLIC_GIT_REVISION || 'unknown',
        guess_uncaught_frames: true,
      },
    },
    environment: process.env.NODE_ENV === 'production' ? 'production' : 'development',
    context: 'frontend',
    custom: {
      application: 'ResilienceAtlas Frontend',
      frontend_url: process.env.NEXT_PUBLIC_FRONTEND_URL || '',
    },
  },
  // Scrub sensitive data
  scrubFields: [
    'password',
    'password_confirmation',
    'access_token',
    'auth_token',
    'secret',
    'api_key',
  ],
  // Transform payload before sending (remove sensitive info from URLs)
  transform: (payload: Record<string, unknown>): void => {
    // Remove sensitive query params from URLs
    const sensitiveParams = ['token', 'key', 'secret', 'password', 'auth'];
    if (
      payload.request &&
      typeof payload.request === 'object' &&
      (payload.request as Record<string, unknown>).url
    ) {
      try {
        const url = new URL((payload.request as Record<string, unknown>).url as string);
        sensitiveParams.forEach((param) => {
          if (url.searchParams.has(param)) {
            url.searchParams.set(param, '[FILTERED]');
          }
        });
        (payload.request as Record<string, unknown>).url = url.toString();
      } catch {
        // Ignore URL parsing errors
      }
    }
    // Payload is mutated in-place, no return value needed
  },
});

// Create singleton Rollbar instance
let rollbarInstance: Rollbar | null = null;

const getRollbar = (): Rollbar | null => {
  if (typeof window === 'undefined') {
    return null; // Don't initialize on server
  }

  if (!rollbarInstance && process.env.NEXT_PUBLIC_ROLLBAR_CLIENT_TOKEN) {
    try {
      rollbarInstance = new Rollbar(getRollbarConfig());
    } catch (error) {
      console.warn('Failed to initialize Rollbar:', error);
      return null;
    }
  }

  return rollbarInstance;
};

// Context for Rollbar instance
interface RollbarContextType {
  rollbar: Rollbar | null;
  logError: (error: Error | string, extra?: Record<string, unknown>) => void;
  logWarning: (message: string, extra?: Record<string, unknown>) => void;
  logInfo: (message: string, extra?: Record<string, unknown>) => void;
  logCritical: (error: Error | string, extra?: Record<string, unknown>) => void;
}

const RollbarContext = createContext<RollbarContextType | null>(null);

// Hook to use Rollbar
export const useRollbar = (): RollbarContextType => {
  const context = useContext(RollbarContext);
  if (!context) {
    // Return a no-op context if not wrapped in provider
    return {
      rollbar: null,
      logError: () => {},
      logWarning: () => {},
      logInfo: () => {},
      logCritical: () => {},
    };
  }
  return context;
};

// Error Boundary Component
interface ErrorBoundaryProps {
  children: ReactNode;
  fallback?: ReactNode;
}

interface ErrorBoundaryState {
  hasError: boolean;
  error: Error | null;
}

export class RollbarErrorBoundary extends Component<ErrorBoundaryProps, ErrorBoundaryState> {
  constructor(props: ErrorBoundaryProps) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error: Error): ErrorBoundaryState {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    // Also log to console for development
    console.error('Error caught by ErrorBoundary:', error, errorInfo);

    // Check rate limiting before sending to Rollbar
    if (rateLimiter.shouldLimit(error)) {
      console.debug('Rollbar: Rate limited error in ErrorBoundary');
      return;
    }

    const rollbar = getRollbar();
    if (rollbar) {
      const suppressed = rateLimiter.getSuppressedCount(error);
      rollbar.error(error, {
        componentStack: errorInfo.componentStack,
        errorBoundary: true,
        ...(suppressed > 0 && { previouslySuppressed: suppressed }),
      });
    }
  }

  render() {
    if (this.state.hasError) {
      if (this.props.fallback) {
        return this.props.fallback;
      }
      return (
        <div
          style={{
            padding: '20px',
            textAlign: 'center',
            fontFamily: 'system-ui, sans-serif',
          }}
        >
          <h2>Something went wrong</h2>
          <p>We&apos;ve been notified and are working on a fix.</p>
          <button
            onClick={() => {
              this.setState({ hasError: false, error: null });
              window.location.reload();
            }}
            style={{
              padding: '10px 20px',
              fontSize: '16px',
              cursor: 'pointer',
              backgroundColor: '#007bff',
              color: 'white',
              border: 'none',
              borderRadius: '4px',
            }}
          >
            Reload Page
          </button>
        </div>
      );
    }

    return this.props.children;
  }
}

// Provider Component
interface RollbarProviderProps {
  children: ReactNode;
}

export const RollbarProvider = ({ children }: RollbarProviderProps) => {
  const rollbarRef = useRef<Rollbar | null>(null);
  const hasWarnedRef = useRef(false);

  useEffect(() => {
    // Initialize Rollbar on mount
    rollbarRef.current = getRollbar();

    // Log if Rollbar is disabled (only once, in development)
    if (!rollbarRef.current && process.env.NODE_ENV === 'development' && !hasWarnedRef.current) {
      console.info(
        'Rollbar is disabled. Set NEXT_PUBLIC_ROLLBAR_CLIENT_TOKEN to enable error tracking.',
      );
      hasWarnedRef.current = true;
    }

    // Cleanup on unmount
    return () => {
      // Rollbar doesn't need explicit cleanup
    };
  }, []);

  const logError = (error: Error | string, extra?: Record<string, unknown>) => {
    // Check rate limiting before sending to Rollbar
    if (rateLimiter.shouldLimit(error, extra)) {
      console.debug('Rollbar: Rate limited error', error);
      return;
    }

    const rollbar = rollbarRef.current || getRollbar();
    if (rollbar) {
      const suppressed = rateLimiter.getSuppressedCount(error, extra);
      rollbar.error(error, {
        ...extra,
        ...(suppressed > 0 && { previouslySuppressed: suppressed }),
      });
    } else {
      console.error('Rollbar Error:', error, extra);
    }
  };

  const logWarning = (message: string, extra?: Record<string, unknown>) => {
    // Check rate limiting before sending to Rollbar
    if (rateLimiter.shouldLimit(message, extra)) {
      console.debug('Rollbar: Rate limited warning', message);
      return;
    }

    const rollbar = rollbarRef.current || getRollbar();
    if (rollbar) {
      const suppressed = rateLimiter.getSuppressedCount(message, extra);
      rollbar.warning(message, {
        ...extra,
        ...(suppressed > 0 && { previouslySuppressed: suppressed }),
      });
    } else {
      console.warn('Rollbar Warning:', message, extra);
    }
  };

  const logInfo = (message: string, extra?: Record<string, unknown>) => {
    const rollbar = rollbarRef.current || getRollbar();
    if (rollbar) {
      rollbar.info(message, extra);
    } else {
      console.info('Rollbar Info:', message, extra);
    }
  };

  const logCritical = (error: Error | string, extra?: Record<string, unknown>) => {
    // Check rate limiting before sending to Rollbar (more lenient for critical errors)
    // Critical errors get a higher threshold - allow 10 per window instead of 5
    if (rateLimiter.shouldLimit(error, extra)) {
      console.debug('Rollbar: Rate limited critical error', error);
      return;
    }

    const rollbar = rollbarRef.current || getRollbar();
    if (rollbar) {
      const suppressed = rateLimiter.getSuppressedCount(error, extra);
      rollbar.critical(error, {
        ...extra,
        ...(suppressed > 0 && { previouslySuppressed: suppressed }),
      });
    } else {
      console.error('Rollbar Critical:', error, extra);
    }
  };

  const contextValue: RollbarContextType = {
    rollbar: rollbarRef.current,
    logError,
    logWarning,
    logInfo,
    logCritical,
  };

  return (
    <RollbarContext.Provider value={contextValue}>
      <RollbarErrorBoundary>{children}</RollbarErrorBoundary>
    </RollbarContext.Provider>
  );
};

// Export utility functions for use outside React components
export const reportError = (error: Error | string, extra?: Record<string, unknown>) => {
  // Check rate limiting before sending to Rollbar
  if (rateLimiter.shouldLimit(error, extra)) {
    console.debug('Rollbar: Rate limited error (outside React)', error);
    return;
  }

  const rollbar = getRollbar();
  if (rollbar) {
    const suppressed = rateLimiter.getSuppressedCount(error, extra);
    rollbar.error(error, {
      ...extra,
      ...(suppressed > 0 && { previouslySuppressed: suppressed }),
    });
  } else {
    console.error('Rollbar Error (outside React):', error, extra);
  }
};

export const reportCritical = (error: Error | string, extra?: Record<string, unknown>) => {
  // Check rate limiting before sending to Rollbar
  if (rateLimiter.shouldLimit(error, extra)) {
    console.debug('Rollbar: Rate limited critical error (outside React)', error);
    return;
  }

  const rollbar = getRollbar();
  if (rollbar) {
    const suppressed = rateLimiter.getSuppressedCount(error, extra);
    rollbar.critical(error, {
      ...extra,
      ...(suppressed > 0 && { previouslySuppressed: suppressed }),
    });
  } else {
    console.error('Rollbar Critical (outside React):', error, extra);
  }
};

export const reportWarning = (message: string, extra?: Record<string, unknown>) => {
  // Check rate limiting before sending to Rollbar
  if (rateLimiter.shouldLimit(message, extra)) {
    console.debug('Rollbar: Rate limited warning (outside React)', message);
    return;
  }

  const rollbar = getRollbar();
  if (rollbar) {
    const suppressed = rateLimiter.getSuppressedCount(message, extra);
    rollbar.warning(message, {
      ...extra,
      ...(suppressed > 0 && { previouslySuppressed: suppressed }),
    });
  } else {
    console.warn('Rollbar Warning (outside React):', message, extra);
  }
};

export const reportInfo = (message: string, extra?: Record<string, unknown>) => {
  // Check rate limiting before sending to Rollbar
  if (rateLimiter.shouldLimit(message, extra)) {
    console.debug('Rollbar: Rate limited info (outside React)', message);
    return;
  }

  const rollbar = getRollbar();
  if (rollbar) {
    const suppressed = rateLimiter.getSuppressedCount(message, extra);
    rollbar.info(message, {
      ...extra,
      ...(suppressed > 0 && { previouslySuppressed: suppressed }),
    });
  } else {
    console.info('Rollbar Info (outside React):', message, extra);
  }
};

// Export rate limiter stats for monitoring/debugging
export const getRateLimiterStats = () => rateLimiter.getStats();

export default RollbarProvider;
