'use client';

import { Component, createContext, useContext, useEffect, useRef, ReactNode } from 'react';
import Rollbar from 'rollbar';

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
  transform: (payload: Record<string, unknown>) => {
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
    return payload;
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
    const rollbar = getRollbar();
    if (rollbar) {
      rollbar.error(error, {
        componentStack: errorInfo.componentStack,
        errorBoundary: true,
      });
    }
    // Also log to console for development
    console.error('Error caught by ErrorBoundary:', error, errorInfo);
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
    const rollbar = rollbarRef.current || getRollbar();
    if (rollbar) {
      rollbar.error(error, extra);
    } else {
      console.error('Rollbar Error:', error, extra);
    }
  };

  const logWarning = (message: string, extra?: Record<string, unknown>) => {
    const rollbar = rollbarRef.current || getRollbar();
    if (rollbar) {
      rollbar.warning(message, extra);
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
    const rollbar = rollbarRef.current || getRollbar();
    if (rollbar) {
      rollbar.critical(error, extra);
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
  const rollbar = getRollbar();
  if (rollbar) {
    rollbar.error(error, extra);
  } else {
    console.error('Rollbar Error (outside React):', error, extra);
  }
};

export const reportCritical = (error: Error | string, extra?: Record<string, unknown>) => {
  const rollbar = getRollbar();
  if (rollbar) {
    rollbar.critical(error, extra);
  } else {
    console.error('Rollbar Critical (outside React):', error, extra);
  }
};

export const reportWarning = (message: string, extra?: Record<string, unknown>) => {
  const rollbar = getRollbar();
  if (rollbar) {
    rollbar.warning(message, extra);
  } else {
    console.warn('Rollbar Warning (outside React):', message, extra);
  }
};

export const reportInfo = (message: string, extra?: Record<string, unknown>) => {
  const rollbar = getRollbar();
  if (rollbar) {
    rollbar.info(message, extra);
  } else {
    console.info('Rollbar Info (outside React):', message, extra);
  }
};

export default RollbarProvider;
