import { useEffect } from 'react';

export const MapOffset = ({ map, sidebarOpened, analysisOpened }) => {
  useEffect(() => {
    const sidebarPanel = document.querySelector('.l-sidebar--fullscreen');
    const analysisPanel = document.querySelector('.analysis-panel');
    const center = map.getCenter();
    const zoom = map.getZoom();
    const offset =
      (sidebarPanel && sidebarOpened ? sidebarPanel.clientWidth : 0) +
      (analysisPanel && analysisOpened ? analysisPanel.clientWidth : 0);

    map.setActiveArea({
      position: 'absolute',
      top: '0',
      left: `${offset}px`,
      right: '0',
      height: '100%',
    });

    map.setView(center, zoom, { animate: true });
  }, [sidebarOpened, analysisOpened]);

  return null;
};
