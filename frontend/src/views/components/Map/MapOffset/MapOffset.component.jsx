import { useEffect } from 'react';

export const MapOffset = ({ map, sidebarOpened, analysisOpened }) => {
  useEffect(() => {
    if (!map) return;

    const sidebarPanel = document.querySelector('.l-sidebar--fullscreen');
    const analysisPanel = document.querySelector('.analysis-panel');
    const leftOffset =
      (sidebarPanel && sidebarOpened ? sidebarPanel.clientWidth : 0) +
      (analysisPanel && analysisOpened ? analysisPanel.clientWidth : 0);

    // OpenLayers uses view.padding = [top, right, bottom, left] to offset the
    // active area — equivalent to Leaflet's setActiveArea plugin.
    const view = map.getView();
    const center = view.getCenter();
    const zoom = view.getZoom();

    view.padding = [0, 0, 0, leftOffset];

    if (center && zoom != null) {
      view.animate({ center, zoom, duration: 300 });
    }
  }, [sidebarOpened, analysisOpened, map]);

  return null;
};
