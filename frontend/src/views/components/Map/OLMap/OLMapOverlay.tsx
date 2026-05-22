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

    // Render children first so the container has its correct size before the pan check
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

    // Pan the map to keep the popup fully visible, accounting for the sidebar on the left
    requestAnimationFrame(() => {
      const element = containerRef.current;
      const overlay = overlayRef.current;
      if (!element || !overlay?.getPosition()) return;

      const view = map.getView();
      const mapEl = map.getTargetElement() as HTMLElement | null;
      if (!mapEl) return;

      const mapRect = mapEl.getBoundingClientRect();
      const rect = element.getBoundingClientRect();
      const resolution = view.getResolution() ?? 1;
      const center = view.getCenter();
      if (!center) return;

      // Detect sidebar so the popup doesn't pan behind it
      const sidebar = document.querySelector<HTMLElement>('.l-sidebar-content');
      const sidebarRight = sidebar ? sidebar.getBoundingClientRect().right : 0;
      const leftMargin = Math.max(sidebarRight - mapRect.left, 0) + 20;
      const MARGIN = 20;

      let dx = 0;
      let dy = 0;

      if (rect.left < mapRect.left + leftMargin) {
        dx = rect.left - (mapRect.left + leftMargin);
      } else if (rect.right > mapRect.right - MARGIN) {
        dx = rect.right - (mapRect.right - MARGIN);
      }

      if (rect.top < mapRect.top + MARGIN) {
        dy = rect.top - (mapRect.top + MARGIN);
      } else if (rect.bottom > mapRect.bottom - MARGIN) {
        dy = rect.bottom - (mapRect.bottom - MARGIN);
      }

      if (dx !== 0 || dy !== 0) {
        view.animate({
          center: [center[0] + dx * resolution, center[1] + dy * resolution],
          duration: 250,
        });
      }
    });
  }, [latlng, data, children]);

  return null;
};

export default OLMapOverlay;
