/**
 * OpenLayers Map component — replaces LeafletMap.
 * Same render-props pattern: children(map) is called once the OL map is ready.
 */
import React, {
  useEffect,
  useRef,
  useState,
  forwardRef,
  useImperativeHandle,
  type ReactNode,
} from 'react';
import OlMap from 'ol/Map';
import View from 'ol/View';
import TileLayer from 'ol/layer/Tile';
import XYZ from 'ol/source/XYZ';
import type BaseLayer from 'ol/layer/Base';
import type { MapBrowserEvent } from 'ol';
import type { Coordinate } from 'ol/coordinate';
import { fromLonLat, toLonLat } from 'ol/proj';
import { defaults as defaultInteractions } from 'ol/interaction/defaults';
import { createBoundaryLayers } from './boundaries';

export interface MapOptions {
  zoom?: number;
  center?: { lat: number; lng: number };
  scrollWheelZoom?: boolean;
  minZoom?: number;
  maxZoom?: number;
  drawControl?: boolean; // no-op in OL, kept for API compatibility
}

export interface BasemapConfig {
  url: string;
  options?: Record<string, unknown>;
}

export interface LabelConfig {
  url: string;
  options?: Record<string, unknown>;
}

export interface MapEvents {
  zoomend?: (map: OlMap) => void;
  dragend?: (map: OlMap) => void;
  click?: (e: MapBrowserEvent<PointerEvent>, map: OlMap) => void;
}

export interface OLMapProps {
  customClass?: string;
  basemap?: BasemapConfig;
  label?: LabelConfig;
  boundaries?: boolean;
  boundaryStyle?: 'light' | 'dark';
  mapOptions?: MapOptions;
  events?: MapEvents;
  children?: (map: OlMap) => ReactNode;
}

export interface OLMapRef {
  getMap: () => OlMap | null;
}

const OLMap = forwardRef<OLMapRef, OLMapProps>(
  (
    {
      customClass = '',
      basemap,
      label,
      boundaries = false,
      boundaryStyle = 'light',
      mapOptions = {},
      events = {},
      children,
    },
    ref,
  ) => {
    const containerRef = useRef<HTMLDivElement>(null);
    const mapRef = useRef<OlMap | null>(null);
    const basemapLayerRef = useRef<TileLayer<XYZ> | null>(null);
    const labelLayerRef = useRef<TileLayer<XYZ> | null>(null);
    const boundaryLayersRef = useRef<BaseLayer[]>([]);
    const prevZoomRef = useRef<number | undefined>(undefined);
    const eventsRef = useRef(events);
    const [mapReady, setMapReady] = useState(false);

    // Keep eventsRef current so handlers always use the latest callbacks
    useEffect(() => {
      eventsRef.current = events;
    }, [events]);

    useImperativeHandle(ref, () => ({
      getMap: () => mapRef.current,
    }));

    // Initialize map once
    useEffect(() => {
      if (!containerRef.current || mapRef.current) return;

      const defaultCenter: Coordinate = fromLonLat([0, 20]);
      const center = mapOptions.center
        ? fromLonLat([mapOptions.center.lng, mapOptions.center.lat])
        : defaultCenter;

      const interactions = defaultInteractions({
        mouseWheelZoom: mapOptions.scrollWheelZoom ?? true,
      });

      const view = new View({
        center,
        zoom: mapOptions.zoom ?? 2,
        minZoom: mapOptions.minZoom ?? 2,
        maxZoom: mapOptions.maxZoom ?? 18,
      });

      const map = new OlMap({
        target: containerRef.current,
        view,
        controls: [],
        interactions,
        layers: [],
      });

      mapRef.current = map;
      prevZoomRef.current = view.getZoom();
      setMapReady(true);

      // Unified moveend handler — split into zoomend vs dragend based on zoom change
      const handleMoveEnd = () => {
        const currentMap = mapRef.current;
        if (!currentMap) return;
        const currentZoom = currentMap.getView().getZoom();
        if (currentZoom !== prevZoomRef.current) {
          prevZoomRef.current = currentZoom;
          eventsRef.current.zoomend?.(currentMap);
        } else {
          eventsRef.current.dragend?.(currentMap);
        }
      };

      const handleClick = (e: MapBrowserEvent<PointerEvent>) => {
        eventsRef.current.click?.(e, mapRef.current!);
      };

      map.on('moveend', handleMoveEnd as never);
      map.on('singleclick', handleClick as never);

      return () => {
        if (mapRef.current) {
          mapRef.current.setTarget(undefined);
          mapRef.current = null;
          setMapReady(false);
        }
      };
      // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);

    // Basemap layer
    useEffect(() => {
      if (!mapRef.current) return;
      if (basemapLayerRef.current) {
        mapRef.current.removeLayer(basemapLayerRef.current);
        basemapLayerRef.current = null;
      }
      if (basemap?.url) {
        const layer = new TileLayer({
          source: new XYZ({ url: basemap.url, crossOrigin: 'anonymous' }),
          zIndex: 0,
          properties: { _systemLayer: true },
        });
        mapRef.current.addLayer(layer);
        basemapLayerRef.current = layer;
      }
    }, [basemap]);

    // Label overlay layer (on top)
    useEffect(() => {
      if (!mapRef.current) return;
      if (labelLayerRef.current) {
        mapRef.current.removeLayer(labelLayerRef.current);
        labelLayerRef.current = null;
      }
      if (label?.url) {
        const layer = new TileLayer({
          source: new XYZ({ url: label.url, crossOrigin: 'anonymous' }),
          zIndex: 1110,
          properties: { _systemLayer: true },
        });
        mapRef.current.addLayer(layer);
        labelLayerRef.current = layer;
      }
    }, [label]);

    // Admin boundary VectorTile overlay
    useEffect(() => {
      if (!mapRef.current) return;
      boundaryLayersRef.current.forEach((l) => mapRef.current?.removeLayer(l));
      boundaryLayersRef.current = [];

      if (!boundaries) return;

      const layers = createBoundaryLayers(boundaryStyle);
      layers.forEach((l) => {
        l.set('_systemLayer', true);
        mapRef.current?.addLayer(l);
      });
      boundaryLayersRef.current = layers;

      return () => {
        layers.forEach((l) => mapRef.current?.removeLayer(l));
        boundaryLayersRef.current = [];
      };
    }, [boundaries, boundaryStyle]);

    // Min/max zoom changes after init
    useEffect(() => {
      if (!mapRef.current) return;
      const view = mapRef.current.getView();
      if (mapOptions.minZoom != null) view.setMinZoom(mapOptions.minZoom);
      if (mapOptions.maxZoom != null) view.setMaxZoom(mapOptions.maxZoom);
    }, [mapOptions.minZoom, mapOptions.maxZoom]);

    return (
      <div className={`c-ol-map ${customClass}`} style={{ width: '100%', height: '100%' }}>
        <div ref={containerRef} style={{ width: '100%', height: '100%' }} />
        {mapReady && mapRef.current && children?.(mapRef.current)}
      </div>
    );
  },
);

OLMap.displayName = 'OLMap';

export { toLonLat };
export default OLMap;
