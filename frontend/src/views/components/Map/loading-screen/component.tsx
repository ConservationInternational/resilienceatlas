import type { CSSProperties } from 'react';

const MapLoadingScreen = ({ styles = {} }: { styles?: CSSProperties }) => (
  <div className="m-map-loading-screen" style={styles}>
    <div className="loader-position">
      <div className="spinner" />
      <span className="text">Loading...</span>
    </div>
  </div>
);

export default MapLoadingScreen;
