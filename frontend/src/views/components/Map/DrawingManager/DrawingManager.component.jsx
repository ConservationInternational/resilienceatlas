import { useEffect, useRef } from 'react';
import qs from 'qs';
import { toLonLat } from 'ol/proj';
import Draw from 'ol/interaction/Draw';
import VectorLayer from 'ol/layer/Vector';
import VectorSource from 'ol/source/Vector';
import GeoJSON from 'ol/format/GeoJSON';
import { isEmpty as extentIsEmpty } from 'ol/extent';

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
  loadGeometry,
}) => {
  const { setParam, removeParam } = useRouterParams();
  const drawInteractionRef = useRef(null);
  const drawSourceRef = useRef(new VectorSource());
  const overlaySourceRef = useRef(new VectorSource());
  const overlayLayerRef = useRef(null);
  const geoJsonFormat = useRef(new GeoJSON());

  // Mount/unmount overlay layer
  useEffect(() => {
    const overlayLayer = new VectorLayer({
      source: overlaySourceRef.current,
      zIndex: 2000,
    });
    overlayLayerRef.current = overlayLayer;
    map.addLayer(overlayLayer);

    // Draw layer (used only during active drawing)
    const drawLayer = new VectorLayer({
      source: drawSourceRef.current,
      zIndex: 2001,
    });
    map.addLayer(drawLayer);

    return () => {
      map.removeLayer(overlayLayer);
      map.removeLayer(drawLayer);
    };
  }, [map]);

  // Wire up Draw interaction
  useEffect(() => {
    const drawInteraction = new Draw({
      source: drawSourceRef.current,
      type: 'Polygon',
    });

    drawInteraction.on('drawstart', () => {
      // Clear overlay when a new draw starts
      overlaySourceRef.current.clear();
    });

    drawInteraction.on('drawend', (event) => {
      const feature = event.feature;
      const geojsonObject = JSON.parse(
        geoJsonFormat.current.writeFeature(feature, {
          dataProjection: 'EPSG:4326',
          featureProjection: 'EPSG:3857',
        }),
      );
      // Clear the draw source after the interaction ends
      setTimeout(() => drawSourceRef.current.clear(), 0);
      setGeojson(geojsonObject);
      setDrawing(false);
    });

    drawInteractionRef.current = drawInteraction;
    return () => {
      map.removeInteraction(drawInteraction);
      drawInteractionRef.current = null;
    };
  }, [map, setDrawing, setGeojson]);

  // Toggle draw interaction
  useEffect(() => {
    if (!drawInteractionRef.current) return;
    if (drawing) {
      map.addInteraction(drawInteractionRef.current);
    } else {
      map.removeInteraction(drawInteractionRef.current);
    }
  }, [drawing, map]);

  // Helper: fit view to an OL extent and update URL params
  const fitAndUpdateUrl = (extent) => {
    if (!extent || extentIsEmpty(extent)) return;
    map.getView().fit(extent, {
      animate: true,
      padding: [50, 50, 50, 50],
      duration: 400,
      callback: () => {
        const view = map.getView();
        setParam('zoom', Math.round(view.getZoom() ?? 2));
        const [lng, lat] = toLonLat(view.getCenter() ?? [0, 20]);
        setParam('center', qs.stringify({ lat, lng }));
      },
    });
  };

  // Reflect geojson state onto overlay layer
  useEffect(() => {
    overlaySourceRef.current.clear();

    if (geojson) {
      const features = geoJsonFormat.current.readFeatures(geojson, {
        dataProjection: 'EPSG:4326',
        featureProjection: 'EPSG:3857',
      });
      overlaySourceRef.current.addFeatures(features);
      map.updateSize();
      fitAndUpdateUrl(overlaySourceRef.current.getExtent());
    } else {
      removeParam('geojson');
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [geojson, map]);

  // Reflect bounds state onto overlay layer
  useEffect(() => {
    if (!bounds) return;
    overlaySourceRef.current.clear();
    const features = geoJsonFormat.current.readFeatures(bounds, {
      dataProjection: 'EPSG:4326',
      featureProjection: 'EPSG:3857',
    });
    overlaySourceRef.current.addFeatures(features);
    map.updateSize();
    fitAndUpdateUrl(overlaySourceRef.current.getExtent());
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [bounds, map]);

  // Reflect ISO country geometry onto overlay layer
  useEffect(() => {
    overlaySourceRef.current.clear();

    if (iso && countries[iso]) {
      const countryEntry = countries[iso];
      if (!countryEntry.geometryLoaded) {
        loadGeometry(iso);
        return;
      }

      const geojsonCountry = JSON.parse(countryEntry.geometry);
      const features = geoJsonFormat.current.readFeatures(geojsonCountry, {
        dataProjection: 'EPSG:4326',
        featureProjection: 'EPSG:3857',
      });
      overlaySourceRef.current.addFeatures(features);
      map.updateSize();
      fitAndUpdateUrl(overlaySourceRef.current.getExtent());
      setParam('iso', iso);
    } else {
      removeParam('iso');
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [iso, countries, map]);

  return null;
};
