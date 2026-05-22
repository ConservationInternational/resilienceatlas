/**
 * OLMapOverlay — renders a positioned React popup using ol/Overlay.
 * Drop-in replacement for LeafletMapPopup.
 */
import React, { useEffect, useRef, type ReactNode } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import Overlay from 'ol/Overlay';
import { fromLonLat } from 'ol/proj';
import type OlMap from 'ol/Map';

interface ForwardedOverlayProps {
  latlng?: { lat: number; lng: number } | null;
  data?: OLMapOverlayProps['data'];
  overlay?: Overlay | null;
}

export interface OLMapOverlayProps {
  map: OlMap;
  latlng?: { lat: number; lng: number } | null;
  data?: {
    layers?: unknown[];
    layersInteraction?: unknown;
    layersInteractionSelected?: unknown;
  };
  onReady?: (overlay: Overlay) => void;
  children?: ReactNode;
}

const OLMapOverlay: React.FC<OLMapOverlayProps> = ({ map, latlng, data, onReady, children }) => {
  const overlayRef = useRef<Overlay | null>(null);
  const containerRef = useRef<HTMLDivElement | null>(null);
  const rootRef = useRef<Root | null>(null);

  // Create the overlay once
  useEffect(() => {
    const container = document.createElement('div');
    container.className = 'ol-popup-content-wrapper';
    containerRef.current = container;

    const overlay = new Overlay({
      element: container,
      positioning: 'bottom-center',
      stopEvent: true,
      offset: [0, -8],
      autoPan: {
        animation: {
          duration: 250,
        },
      },
    });

    map.addOverlay(overlay);
    overlayRef.current = overlay;
    onReady?.(overlay);

    return () => {
      if (rootRef.current) {
        rootRef.current.unmount();
        rootRef.current = null;
      }
      map.removeOverlay(overlay);
      overlayRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Position + render children when latlng or data changes
  useEffect(() => {
    if (!overlayRef.current || !containerRef.current) return;

    if (!latlng) {
      overlayRef.current.setPosition(undefined);
      return;
    }

    const coord = fromLonLat([latlng.lng, latlng.lat]);
    overlayRef.current.setPosition(coord);

    if (children) {
      if (!rootRef.current) {
        rootRef.current = createRoot(containerRef.current);
      }
      const forwardedProps: ForwardedOverlayProps = {
        latlng,
        data,
        overlay: overlayRef.current,
      };
      rootRef.current.render(
        <>
          {React.Children.map(children, (child) =>
            React.isValidElement(child) ? React.cloneElement(child, forwardedProps) : child,
          )}
        </>,
      );
    }
  }, [latlng, data, children]);

  return null;
};

export default OLMapOverlay;
