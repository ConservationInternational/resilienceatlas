import { useEffect, useRef } from 'react';
import qs from 'qs';

import { useRouterParams } from 'utilities';

export const DrawingManager = ({
  setGeojson,
  setDrawing,
  map,
  drawing,
  geojson,
  bounds,
  iso,
  countries,
}) => {
  const { setParam, removeParam } = useRouterParams();
  const layer = useRef(null);

  useEffect(() => {
    // Define event handlers
    const handleDrawStart = () => {
      if (layer.current) {
        setGeojson(null);
      }
    };

    const handleCreate = (e) => {
      layer.current = e.layer;
      setGeojson(e.layer.toGeoJSON());
      setDrawing(false);
    };

    // bind pm events
    map.on('pm:drawstart', handleDrawStart);
    map.on('pm:create', handleCreate);

    // Cleanup function
    return () => {
      map.off('pm:drawstart', handleDrawStart);
      map.off('pm:create', handleCreate);
    };
  }, [map, setDrawing, setGeojson]);

  // drawing toggler
  useEffect(() => {
    if (drawing) {
      map.pm.enableDraw('Polygon');
    } else {
      map.pm.disableDraw('Polygon');
    }
  }, [drawing, map.pm]);

  // clear drawing if deleted from redux
  useEffect(() => {
    if (layer.current) {
      // clear if geojson exists and was updated
      layer.current.remove();
      map.removeLayer(layer.current);
    }

    if (geojson) {
      layer.current = L.geoJSON(geojson);
      layer.current.setZIndex(2000);
      layer.current.addTo(map);

      const layerBounds = layer.current.getBounds();
      map.invalidateSize();

      map.fitBounds(layerBounds, { animate: true, padding: [50, 50] });

      setParam('zoom', map.getZoom());
      setParam('center', qs.stringify(layerBounds.getCenter()));
      // setParam('geojson', JSON.stringify(geojson));
    } else {
      removeParam('geojson');
    }
  }, [geojson, map, setParam, removeParam]);

  useEffect(() => {
    if (bounds) {
      const mapBounds = L.geoJSON(bounds).getBounds();

      map.invalidateSize();

      map.fitBounds(mapBounds, { animate: true, padding: [50, 50] });

      setParam('zoom', map.getZoom());
      setParam('center', qs.stringify(mapBounds.getCenter()));
    }
  }, [bounds, map, setParam]);

  useEffect(() => {
    if (layer.current) {
      // clear if geojson exists and was updated
      layer.current.remove();
      map.removeLayer(layer.current);
    }

    if (iso && countries[iso]) {
      const geojson_country = JSON.parse(countries[iso].geometry);

      layer.current = L.geoJSON(geojson_country);
      layer.current.setZIndex(2000);
      layer.current.addTo(map);

      const layerBounds = layer.current.getBounds();
      map.invalidateSize();

      map.fitBounds(layerBounds, { animate: true, padding: [50, 50] });

      setParam('zoom', map.getZoom());
      setParam('center', qs.stringify(layerBounds.getCenter()));
      setParam('iso', iso);
    } else {
      removeParam('iso');
    }
  }, [iso, countries, map, setParam, removeParam]);

  return null;
};
