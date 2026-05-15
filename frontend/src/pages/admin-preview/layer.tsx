/**
 * Layer Map Preview Page
 *
 * Minimal iframe-embeddable page that renders a Leaflet map with the layer being
 * edited in the admin tool. Receives layer config via postMessage from Rails admin.
 *
 * Reuses the existing LeafletMap, LayerManager, Layer components and PluginLeaflet
 * — no logic is duplicated from the frontend.
 *
 * Usage:
 *   <iframe src="/admin-preview/layer?adminOrigin=http://localhost:3001" />
 *
 * Then send:
 *   iframe.contentWindow.postMessage({
 *     type: 'LAYER_PREVIEW',
 *     provider: 'cartodb',    // layer_provider field
 *     query: 'SELECT ...',    // SQL query (cartodb/raster)
 *     css: '#layer { ... }',  // CartoCSS (cartodb/raster)
 *     layer_config: '{}',     // JSON string (cog/martin/xyz/gee/leaflet)
 *     carto_account: 'cdb',   // optional, defaults to 'cdb'
 *   }, '*')
 */

// Import Leaflet statically (same pattern as Map.component.tsx)
import L from 'leaflet';

// Layer-manager components require window — loaded client-side only
// eslint-disable-next-line @typescript-eslint/consistent-type-imports
let LayerManager: typeof import('lib/layer-manager/components').LayerManager;
// eslint-disable-next-line @typescript-eslint/consistent-type-imports
let Layer: typeof import('lib/layer-manager/components').Layer;
// eslint-disable-next-line @typescript-eslint/consistent-type-imports
let PluginLeaflet: typeof import('lib/layer-manager/plugins/plugin-leaflet').default;

if (typeof window !== 'undefined') {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  (window as any).L = L;

  const components = require('lib/layer-manager/components');
  LayerManager = components.LayerManager;
  Layer = components.Layer;

  const lm = require('lib/layer-manager/plugins/plugin-leaflet');
  PluginLeaflet = lm.default;
}

import { useState, useEffect, useCallback, type ReactElement } from 'react';
import { LeafletMap } from 'views/components/Map/LeafletMap/exports';
import type { NextPageWithLayout } from 'pages/_app';
import basemaps from 'views/utils/basemaps.json';

// ─── Layer spec builder (mirrors schema.js processStrategy logic) ─────────────

interface LayerSpec {
  id: string;
  type: string;
  layerConfig: Record<string, unknown>;
  opacity: number;
  visibility: boolean;
  slug: string;
}

type ProviderLayerConfig = Record<string, unknown>;

function buildLayerConfig(
  provider: string,
  query: string,
  css: string,
  layerConfigJson: string,
  cartoAccount: string,
): ProviderLayerConfig | null {
  let layerConfig: Record<string, unknown> = {};
  try {
    if (layerConfigJson) {
      layerConfig = JSON.parse(layerConfigJson);
    }
  } catch {
    // Invalid JSON — use empty config
  }

  const minzoom = (layerConfig as { zoom_min?: number }).zoom_min;
  const maxzoom = (layerConfig as { zoom_max?: number }).zoom_max;
  const body = (layerConfig as { body?: Record<string, unknown> }).body || {};
  const source = body.source || (layerConfig as { source?: unknown }).source;
  const styles: Record<string, unknown> = (body.styles as Record<string, unknown> | undefined) ?? {};
  const options: Record<string, unknown> = (body.options as Record<string, unknown> | undefined) ?? {};

  switch (provider) {
    case 'cartodb':
    case 'carto':
      return {
        body: {
          layers: [
            {
              options: {
                cartocss: css,
                cartocss_version: '2.1.0',
                sql: query,
              },
              type: 'mapnik',
            },
          ],
          minzoom,
          maxzoom,
        },
        account: cartoAccount || 'cdb',
      };

    case 'raster':
      return {
        body: {
          layers: [
            {
              options: {
                cartocss: css,
                cartocss_version: '2.3.0',
                sql: query,
                raster: true,
                raster_band: 1,
                geom_column: 'the_raster_webmercator',
                geom_type: 'raster',
              },
              type: 'cartodb',
            },
          ],
          minzoom,
          maxzoom,
        },
        account: cartoAccount || 'cdb',
      };

    case 'xyz tileset':
      return {
        type: 'tileLayer',
        body: {
          ...body,
          url: (body.url as string) || (layerConfig.url as string) || query,
        },
      };

    case 'gee':
      return {
        ...layerConfig,
        type: (layerConfig.type as string) || 'tileLayer',
        body: { ...body },
      };

    case 'cog': {
      const cogUrl = (body.url as string) || (layerConfig.url as string);
      return {
        ...layerConfig,
        parse: false,
        type: (layerConfig.type as string) || 'tileLayer',
        body: {
          ...body,
          url: cogUrl,
        },
      };
    }

    case 'leaflet':
      return {
        ...layerConfig,
        type: (layerConfig.type as string) || 'tileLayer',
        body: {
          ...body,
          url: (body.url as string) || (layerConfig.url as string),
        },
      };

    case 'martin':
      return {
        ...layerConfig,
        body: {
          source,
          styles,
          options: {
            interactive: true,
            maxNativeZoom: maxzoom || 14,
            ...options,
          },
        },
      };

    default:
      return null;
  }
}

function buildLayerSpec(
  provider: string,
  query: string,
  css: string,
  layerConfigJson: string,
  cartoAccount: string,
): LayerSpec | null {
  const layerConfig = buildLayerConfig(provider, query, css, layerConfigJson, cartoAccount);
  if (!layerConfig) return null;

  return {
    id: 'admin-preview',
    slug: 'admin-preview',
    type: provider,
    layerConfig,
    opacity: 1,
    visibility: true,
  };
}

// ─── Preview message payload ──────────────────────────────────────────────────

interface LayerPreviewMessage {
  type: 'LAYER_PREVIEW';
  provider: string;
  query: string;
  css: string;
  layer_config: string;
  carto_account?: string;
}

// ─── Page component ───────────────────────────────────────────────────────────

const LayerPreviewPage: NextPageWithLayout = () => {
  const [layerSpec, setLayerSpec] = useState<LayerSpec | null>(null);
  const [status, setStatus] = useState<'waiting' | 'ready' | 'error'>('waiting');
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [adminOrigin, setAdminOrigin] = useState<string | null>(null);

  // Read adminOrigin from URL query param on mount
  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const origin = params.get('adminOrigin');
    if (origin) setAdminOrigin(decodeURIComponent(origin));
  }, []);

  const applyPreviewMessage = useCallback((msg: LayerPreviewMessage) => {
    const { provider, query = '', css = '', layer_config = '', carto_account = 'cdb' } = msg;
    setErrorMsg(null);

    if (!provider) {
      setStatus('error');
      setErrorMsg('No layer provider specified.');
      return;
    }

    const spec = buildLayerSpec(provider, query, css, layer_config, carto_account);
    if (!spec) {
      setStatus('error');
      setErrorMsg(`Unknown layer provider: "${provider}"`);
      return;
    }

    // Clear spec first so Layer unmounts, then re-mount with new spec.
    // This ensures LayerManager removes the old layer before adding the new one.
    setLayerSpec(null);
    requestAnimationFrame(() => {
      setLayerSpec(spec);
      setStatus('ready');
    });
  }, []);

  // Listen for postMessage from admin iframe parent
  useEffect(() => {
    const handleMessage = (event: MessageEvent) => {
      if (adminOrigin && event.origin !== adminOrigin) return;

      if (event.data?.type === 'LAYER_PREVIEW') {
        applyPreviewMessage(event.data as LayerPreviewMessage);
      }
    };

    window.addEventListener('message', handleMessage);
    return () => window.removeEventListener('message', handleMessage);
  }, [adminOrigin, applyPreviewMessage]);

  const basemapConfig = {
    url: basemaps.defaultmap.url,
    options: {},
  };

  return (
    <div style={styles.container}>
      {status === 'waiting' && (
        <div style={styles.overlay}>
          <span style={styles.placeholderText}>Waiting for layer data&hellip;</span>
        </div>
      )}

      {status === 'error' && (
        <div style={styles.overlay}>
          <span style={styles.errorText}>
            <strong>Error:</strong> {errorMsg}
          </span>
        </div>
      )}

      <LeafletMap
        basemap={basemapConfig}
        mapOptions={{ zoom: 2, center: [20, 0], minZoom: 2, maxZoom: 18 }}
      >
        {(map) =>
          layerSpec && LayerManager && Layer && PluginLeaflet ? (
            <LayerManager map={map} plugin={PluginLeaflet}>
              <Layer {...layerSpec} />
            </LayerManager>
          ) : null
        }
      </LeafletMap>
    </div>
  );
};

// No top-level site layout — bare page suitable for iframe embedding
LayerPreviewPage.Layout = (page: ReactElement) => page;

export default LayerPreviewPage;

// ─── Inline styles ────────────────────────────────────────────────────────────

const styles = {
  container: {
    position: 'relative' as const,
    width: '100%',
    height: '100vh',
    overflow: 'hidden',
  },
  overlay: {
    position: 'absolute' as const,
    top: 0,
    left: 0,
    right: 0,
    zIndex: 1000,
    background: 'rgba(255,255,255,0.85)',
    padding: '8px 12px',
    textAlign: 'center' as const,
    fontSize: '13px',
  },
  placeholderText: {
    color: '#999',
    fontStyle: 'italic' as const,
  },
  errorText: {
    color: '#c00',
  },
};
