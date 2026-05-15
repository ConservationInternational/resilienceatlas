/**
 * Legend Preview Page
 *
 * Minimal iframe-embeddable page for previewing layer legends in the admin.
 * Receives legend JSON via postMessage from the Rails admin tool (port 3001).
 *
 * Usage:
 *   <iframe src="/admin-preview/legend?adminOrigin=http://localhost:3001" />
 *
 * Then send: iframe.contentWindow.postMessage({ type: 'LEGEND_PREVIEW', legend: '<json>' }, '*')
 */
import { useState, useEffect, type ReactElement } from 'react';
import LegendItem from 'views/components/Legend/LegendItem';
import type { NextPageWithLayout } from 'pages/_app';

const LegendPreviewPage: NextPageWithLayout = () => {
  const [legendJson, setLegendJson] = useState<string | null>(null);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [adminOrigin, setAdminOrigin] = useState<string | null>(null);

  // Read adminOrigin and optional initial data from URL query params (client-side only)
  useEffect(() => {
    const params = new URLSearchParams(window.location.search);

    const origin = params.get('adminOrigin');
    if (origin) setAdminOrigin(decodeURIComponent(origin));

    // Optional: pre-load legend data from a base64-encoded ?data= query param
    const data = params.get('data');
    if (data) {
      try {
        setLegendJson(atob(data));
      } catch {
        // Ignore invalid base64
      }
    }
  }, []);

  // Listen for postMessage updates from the admin iframe parent
  useEffect(() => {
    const handleMessage = (event: MessageEvent) => {
      // Validate origin once we have it — reject messages from unexpected origins
      if (adminOrigin && event.origin !== adminOrigin) return;

      if (event.data?.type === 'LEGEND_PREVIEW') {
        setErrorMsg(null);
        setLegendJson(event.data.legend ?? null);
      }
    };

    window.addEventListener('message', handleMessage);
    return () => window.removeEventListener('message', handleMessage);
  }, [adminOrigin]);

  // Catch rendering errors from invalid legend JSON
  let content: ReactElement;
  if (errorMsg) {
    content = (
      <div style={styles.error}>
        <strong>Error:</strong> {errorMsg}
      </div>
    );
  } else if (legendJson) {
    content = (
      // Wrap in .side-bar > .m-legend to inherit the correct scoped SCSS styles
      // (.side-bar context resets .m-legend to position:static)
      <div className="side-bar">
        <div
          className="m-legend"
          style={{ position: 'static', boxShadow: 'none', padding: '0', width: '100%', background: 'transparent' }}
        >
          <LegendErrorBoundary onError={setErrorMsg}>
            <LegendItem legend={legendJson} layer={{ id: 'admin-preview', chartLimit: 100 }} />
          </LegendErrorBoundary>
        </div>
      </div>
    );
  } else {
    content = (
      <div style={styles.placeholder}>
        Waiting for legend data&hellip;
      </div>
    );
  }

  return (
    <div style={styles.container}>
      {content}
    </div>
  );
};

// No layout — bare page suitable for iframe embedding
LegendPreviewPage.Layout = (page) => page;

export default LegendPreviewPage;

// ─── Legend Error Boundary ────────────────────────────────────────────────────

import { Component, type ErrorInfo } from 'react';

interface ErrorBoundaryProps {
  children: ReactElement;
  onError: (message: string) => void;
}
interface ErrorBoundaryState {
  hasError: boolean;
}

class LegendErrorBoundary extends Component<ErrorBoundaryProps, ErrorBoundaryState> {
  state: ErrorBoundaryState = { hasError: false };

  static getDerivedStateFromError(): ErrorBoundaryState {
    return { hasError: true };
  }

  componentDidCatch(error: Error, _info: ErrorInfo) {
    this.props.onError(error.message);
  }

  componentDidUpdate(prevProps: ErrorBoundaryProps) {
    // Reset on new legend data
    if (prevProps.children !== this.props.children && this.state.hasError) {
      this.setState({ hasError: false });
    }
  }

  render() {
    if (this.state.hasError) return null;
    return this.props.children;
  }
}

// ─── Inline styles ────────────────────────────────────────────────────────────

const styles = {
  container: {
    padding: '12px',
    background: 'white',
    minHeight: '100vh',
    fontFamily: 'Arial, sans-serif',
    boxSizing: 'border-box' as const,
  },
  placeholder: {
    color: '#999',
    fontSize: '13px',
    fontStyle: 'italic' as const,
    padding: '8px 0',
  },
  error: {
    color: '#c00',
    fontSize: '13px',
    padding: '8px',
    background: '#fff0f0',
    border: '1px solid #ffcccc',
    borderRadius: '3px',
  },
};
