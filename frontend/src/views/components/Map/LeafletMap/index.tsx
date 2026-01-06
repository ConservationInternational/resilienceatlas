/**
 * Native Leaflet Map component to replace vizzuality-components
 * This provides React 19 compatible Leaflet integration
 */
import React, {
  useEffect,
  useRef,
  useCallback,
  useState,
  forwardRef,
  useImperativeHandle,
  type ReactNode,
} from 'react';
import L from 'leaflet';

export interface MapOptions extends L.MapOptions {
  zoom?: number;
  center?: L.LatLngExpression;
  scrollWheelZoom?: boolean;
  drawControl?: boolean;
  minZoom?: number;
  maxZoom?: number;
}

export interface BasemapConfig {
  url: string;
  options?: L.TileLayerOptions;
}

export interface LabelConfig {
  url: string;
  options?: L.TileLayerOptions;
}

export interface MapEvents {
  layeradd?: (e: L.LayerEvent, map: L.Map) => void;
  zoomend?: (e: L.LeafletEvent, map: L.Map) => void;
  dragend?: (e: L.DragEndEvent, map: L.Map) => void;
  click?: (e: L.LeafletMouseEvent, map: L.Map) => void;
  moveend?: (e: L.LeafletEvent, map: L.Map) => void;
}

export interface LeafletMapProps {
  customClass?: string;
  basemap?: BasemapConfig;
  label?: LabelConfig;
  mapOptions?: MapOptions;
  events?: MapEvents;
  children?: (map: L.Map) => ReactNode;
}

export interface LeafletMapRef {
  getMap: () => L.Map | null;
}

const LeafletMap = forwardRef<LeafletMapRef, LeafletMapProps>(
  ({ customClass = '', basemap, label, mapOptions = {}, events = {}, children }, ref) => {
    const containerRef = useRef<HTMLDivElement>(null);
    const mapRef = useRef<L.Map | null>(null);
    const basemapLayerRef = useRef<L.TileLayer | null>(null);
    const labelLayerRef = useRef<L.TileLayer | null>(null);
    const [mapReady, setMapReady] = useState(false);

    // Expose map instance to parent via ref
    useImperativeHandle(ref, () => ({
      getMap: () => mapRef.current,
    }));

    // Initialize map
    useEffect(() => {
      if (!containerRef.current || mapRef.current) return;

      const defaultCenter: L.LatLngExpression = [0, 0];
      const defaultZoom = 5;

      const map = L.map(containerRef.current, {
        center: mapOptions.center || defaultCenter,
        zoom: mapOptions.zoom || defaultZoom,
        scrollWheelZoom: mapOptions.scrollWheelZoom ?? true,
        minZoom: mapOptions.minZoom || 2,
        maxZoom: mapOptions.maxZoom || 18,
        zoomControl: false, // We'll add our own zoom control
        ...mapOptions,
      });

      mapRef.current = map;
      setMapReady(true);

      // Cleanup on unmount
      return () => {
        if (mapRef.current) {
          mapRef.current.remove();
          mapRef.current = null;
          setMapReady(false);
        }
      };
      // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);

    // Handle basemap layer
    useEffect(() => {
      if (!mapRef.current) return;

      // Remove existing basemap layer
      if (basemapLayerRef.current) {
        mapRef.current.removeLayer(basemapLayerRef.current);
        basemapLayerRef.current = null;
      }

      // Add new basemap layer
      if (basemap?.url) {
        basemapLayerRef.current = L.tileLayer(basemap.url, {
          ...basemap.options,
          zIndex: 0,
        }).addTo(mapRef.current);
      }
    }, [basemap]);

    // Handle label layer
    useEffect(() => {
      if (!mapRef.current) return;

      // Remove existing label layer
      if (labelLayerRef.current) {
        mapRef.current.removeLayer(labelLayerRef.current);
        labelLayerRef.current = null;
      }

      // Add new label layer (on top of everything)
      if (label?.url) {
        labelLayerRef.current = L.tileLayer(label.url, {
          ...label.options,
          zIndex: 1000,
          pane: 'overlayPane',
        }).addTo(mapRef.current);
      }
    }, [label]);

    // Handle events
    useEffect(() => {
      if (!mapRef.current) return;

      const map = mapRef.current;

      const handlers: { [key: string]: L.LeafletEventHandlerFn } = {};

      if (events.layeradd) {
        handlers.layeradd = (e: L.LayerEvent) => events.layeradd!(e, map);
        map.on('layeradd', handlers.layeradd);
      }

      if (events.zoomend) {
        handlers.zoomend = (e: L.LeafletEvent) => events.zoomend!(e, map);
        map.on('zoomend', handlers.zoomend);
      }

      if (events.dragend) {
        handlers.dragend = (e: L.DragEndEvent) => events.dragend!(e, map);
        map.on('dragend', handlers.dragend);
      }

      if (events.click) {
        handlers.click = (e: L.LeafletMouseEvent) => events.click!(e, map);
        map.on('click', handlers.click);
      }

      if (events.moveend) {
        handlers.moveend = (e: L.LeafletEvent) => events.moveend!(e, map);
        map.on('moveend', handlers.moveend);
      }

      return () => {
        Object.entries(handlers).forEach(([eventName, handler]) => {
          map.off(eventName, handler);
        });
      };
    }, [events]);

    // Update map options when they change
    useEffect(() => {
      if (!mapRef.current) return;

      const map = mapRef.current;

      if (mapOptions.center) {
        const currentCenter = map.getCenter();
        const newCenter = L.latLng(mapOptions.center);
        if (
          Math.abs(currentCenter.lat - newCenter.lat) > 0.0001 ||
          Math.abs(currentCenter.lng - newCenter.lng) > 0.0001
        ) {
          map.setView(newCenter, mapOptions.zoom || map.getZoom(), { animate: false });
        }
      }

      if (mapOptions.zoom && map.getZoom() !== mapOptions.zoom) {
        map.setZoom(mapOptions.zoom);
      }

      if (mapOptions.minZoom) {
        map.setMinZoom(mapOptions.minZoom);
      }

      if (mapOptions.maxZoom) {
        map.setMaxZoom(mapOptions.maxZoom);
      }
    }, [mapOptions.center, mapOptions.zoom, mapOptions.minZoom, mapOptions.maxZoom]);

    return (
      <div className={`c-leaflet-map ${customClass}`} style={{ width: '100%', height: '100%' }}>
        <div ref={containerRef} style={{ width: '100%', height: '100%' }} />
        {mapReady && mapRef.current && children?.(mapRef.current)}
      </div>
    );
  },
);

LeafletMap.displayName = 'LeafletMap';

export default LeafletMap;
