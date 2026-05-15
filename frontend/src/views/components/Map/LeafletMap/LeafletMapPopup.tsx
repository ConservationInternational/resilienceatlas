// @ts-nocheck
/**
 * Map Popup component for Leaflet
 * Displays a popup at a specific location on the map
 */
import React, { useEffect, useRef, type ReactNode } from 'react';
import L from 'leaflet';
import { createRoot, type Root } from 'react-dom/client';

// Props that LeafletMapPopup forwards to each direct child element
interface ForwardedPopupProps {
  latlng?: L.LatLngExpression | null;
  data?: LeafletMapPopupProps['data'];
  popup?: L.Popup | null;
}

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

    // Call onReady before rendering so children that receive the popup ref can call popup.remove()
    if (onReady && popupRef.current) {
      onReady(popupRef.current);
    }

    // Render React children into popup, forwarding popup-related props
    if (containerRef.current && children) {
      if (!rootRef.current) {
        rootRef.current = createRoot(containerRef.current);
      }
      const forwardedProps: ForwardedPopupProps = {
        latlng,
        data,
        popup: popupRef.current,
      };
      rootRef.current.render(
        <>
          {React.Children.map(children, (child) =>
            React.isValidElement(child) ? React.cloneElement(child, forwardedProps) : child,
          )}
        </>,
      );
    }
  }, [map, latlng, children, onReady]);

  // Update content when data changes
  useEffect(() => {
    if (containerRef.current && children && rootRef.current) {
      const forwardedProps: ForwardedPopupProps = {
        latlng,
        data,
        popup: popupRef.current,
      };
      rootRef.current.render(
        <>
          {React.Children.map(children, (child) =>
            React.isValidElement(child) ? React.cloneElement(child, forwardedProps) : child,
          )}
        </>,
      );
    }
  }, [data, children]);

  return null;
};

export default LeafletMapPopup;
