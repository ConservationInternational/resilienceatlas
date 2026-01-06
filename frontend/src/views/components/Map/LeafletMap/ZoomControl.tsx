/**
 * Zoom Control component for Leaflet map
 * Provides zoom in/out buttons with SVG icons matching vizzuality-components style
 */
import React, { useCallback } from 'react';
import type L from 'leaflet';

export interface ZoomControlProps {
  map: L.Map;
  customClass?: string;
}

const ZoomControl: React.FC<ZoomControlProps> = ({ map, customClass = '' }) => {
  const handleZoomIn = useCallback(() => {
    if (map) {
      map.zoomIn();
    }
  }, [map]);

  const handleZoomOut = useCallback(() => {
    if (map) {
      map.zoomOut();
    }
  }, [map]);

  return (
    <div className={`c-zoom-control ${customClass}`}>
      <button
        type="button"
        className="zoom-control-btn zoom-in"
        onClick={handleZoomIn}
        aria-label="Zoom in"
        title="Zoom in"
      >
        <svg className="icon icon-plus" viewBox="0 0 32 32">
          <path d="M13.865 5v8.8h-8.865v4.4h8.865v8.8h4.271v-8.8h8.865v-4.4h-8.865v-8.8z" />
        </svg>
      </button>
      <button
        type="button"
        className="zoom-control-btn zoom-out"
        onClick={handleZoomOut}
        aria-label="Zoom out"
        title="Zoom out"
      >
        <svg className="icon icon-minus" viewBox="0 0 32 32">
          <path d="M5.5 17.909h20.894v-3.818h-20.894z" />
        </svg>
      </button>
    </div>
  );
};

export default ZoomControl;
