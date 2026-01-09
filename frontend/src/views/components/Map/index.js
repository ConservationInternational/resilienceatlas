import dynamic from 'next/dynamic';
import React from 'react';

// Error boundary to catch rendering errors
class MapErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }

  componentDidCatch(error, errorInfo) {
    console.error('[MapErrorBoundary] Caught error:', error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      return (
        <div style={{ padding: 20, color: 'red', background: '#fff' }}>
          <h3>Map failed to load</h3>
          <pre>{this.state.error?.message || 'Unknown error'}</pre>
        </div>
      );
    }
    return this.props.children;
  }
}

// Dynamic import to prevent SSR issues with Leaflet
// Leaflet and its plugins require `window` which doesn't exist on the server
const MapContainerDynamic = dynamic(
  () =>
    import('./Map.container')
      .then((mod) => {
        console.log('[Map/index.js] Map.container loaded successfully');
        return mod;
      })
      .catch((err) => {
        console.error('[Map/index.js] Failed to load Map.container:', err);
        throw err;
      }),
  {
    ssr: false,
    loading: () => (
      <div style={{ width: '100%', height: '100%', background: '#f0f0f0' }}>Loading map...</div>
    ),
  },
);

const MapContainer = (props) => (
  <MapErrorBoundary>
    <MapContainerDynamic {...props} />
  </MapErrorBoundary>
);

export default MapContainer;
