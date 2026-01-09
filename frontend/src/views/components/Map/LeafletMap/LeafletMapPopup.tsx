/**
 * Map Popup component for Leaflet
 * Displays a popup at a specific location on the map
 */
import React, { useEffect, useRef, type ReactNode } from 'react';
import L from 'leaflet';
import { createRoot, type Root } from 'react-dom/client';

export interface LeafletMapPopupProps {
  map: L.Map;
  latlng?: L.LatLngExpression | null;
  data?: {
    layers?: unknown[];
    layersInteraction?: unknown;
    layersInteractionSelected?: unknown;
  };
  onReady?: (popup: L.Popup) => void;
  children?: ReactNode;
}

const LeafletMapPopup: React.FC<LeafletMapPopupProps> = ({
  map,
  latlng,
  data,
  onReady,
  children,
}) => {
  const popupRef = useRef<L.Popup | null>(null);
  const containerRef = useRef<HTMLDivElement | null>(null);
  const rootRef = useRef<Root | null>(null);

  useEffect(() => {
    // Clean up on unmount
    return () => {
      if (popupRef.current) {
        popupRef.current.remove();
        popupRef.current = null;
      }
      if (rootRef.current) {
        rootRef.current.unmount();
        rootRef.current = null;
      }
    };
  }, []);

  useEffect(() => {
    if (!map || !latlng) {
      // Remove popup if no latlng
      if (popupRef.current) {
        popupRef.current.remove();
        popupRef.current = null;
      }
      return;
    }

    // Create container for React content
    if (!containerRef.current) {
      containerRef.current = document.createElement('div');
      containerRef.current.className = 'leaflet-popup-content-wrapper-react';
    }

    // Create or update popup
    if (!popupRef.current) {
      popupRef.current = L.popup({
        closeButton: true,
        className: 'c-layer-popup',
        maxWidth: 400,
        minWidth: 240,
      });
    }

    popupRef.current.setLatLng(latlng as L.LatLngExpression);
    popupRef.current.setContent(containerRef.current);

    if (!map.hasLayer(popupRef.current as unknown as L.Layer)) {
      popupRef.current.openOn(map);
    }

    // Render React children into popup
    if (containerRef.current && children) {
      if (!rootRef.current) {
        rootRef.current = createRoot(containerRef.current);
      }
      rootRef.current.render(<>{children}</>);
    }

    if (onReady && popupRef.current) {
      onReady(popupRef.current);
    }
  }, [map, latlng, children, onReady]);

  // Update content when data changes
  useEffect(() => {
    if (containerRef.current && children && rootRef.current) {
      rootRef.current.render(<>{children}</>);
    }
  }, [data, children]);

  return null;
};

export default LeafletMapPopup;
