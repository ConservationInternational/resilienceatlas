/**
 * Layer Map Preview Page
 *
 * Minimal iframe-embeddable page that renders an OLMap with the layer being
 * edited in the admin tool. Receives layer config via postMessage from Rails admin.
 *
 * Reuses the existing OLMap, LayerManager, Layer components and PluginOpenLayers
 * — no logic is duplicated from the frontend.
 *
 * Usage:
 *   <iframe src="/admin-preview/layer?adminOrigin=http://localhost:3001" />
 *
 * Then send:
 *   iframe.contentWindow.postMessage({
 *     type: 'LAYER_PREVIEW',
 *     provider: 'cog',        // layer_provider field (cog/esri/gee/leaflet/martin/wms/wmts/'xyz tileset')
 *     layer_config: '{}',     // JSON string
 *   }, '*')
 */

import dynamic from 'next/dynamic';
import { useState, useEffect, useCallback, type ReactElement } from 'react';
import type { OLMapProps } from 'views/components/Map/OLMap/exports';
import type { NextPageWithLayout } from 'pages/_app';
import basemaps from 'views/utils/basemaps.json';

// OLMap uses browser APIs — must be client-side only
const OLMap = dynamic<OLMapProps>(
  () => import('views/components/Map/OLMap/exports').then((m) => ({ default: m.OLMap })),
  { ssr: false },
);

// All browser-only libraries — loaded client-side only
// eslint-disable-next-line @typescript-eslint/consistent-type-imports
let LayerManager: typeof import('lib/layer-manager/components').LayerManager;
// eslint-disable-next-line @typescript-eslint/consistent-type-imports
let Layer: typeof import('lib/layer-manager/components').Layer;
// eslint-disable-next-line @typescript-eslint/consistent-type-imports
let PluginOpenLayers: typeof import('lib/layer-manager/plugins/plugin-openlayers').default;

if (typeof window !== 'undefined') {
  const components = require('lib/layer-manager/components');
  LayerManager = components.LayerManager;
  Layer = components.Layer;

  const lm = require('lib/layer-manager/plugins/plugin-openlayers');
  PluginOpenLayers = lm.default;
}

// ─── Layer spec builder (mirrors schema.js processStrategy logic) ─────────────

// Maps layer_provider values to the plugin method keys used by PluginOpenLayers.method
// Must match Layer::VALID_PROVIDERS in backend/app/models/layer.rb
const PROVIDER_MAP: Record<string, string> = {
  cog: 'cog',
  esri: 'arcgis',
  gee: 'gee',
  leaflet: 'leaflet',
  martin: 'martin',
  wms: 'wms',
  wmts: 'wmts',
  'xyz tileset': 'xyz tileset',
};

interface LayerSpec {
  id: string;
  type: string;
  provider: string;
  layerConfig: Record<string, unknown>;
  opacity: number;
  visibility: boolean;
  slug: string;
}

type ProviderLayerConfig = Record<string, unknown>;

function buildLayerConfig(
  provider: string,
  layerConfigJson: string,
): ProviderLayerConfig | null {
  let layerConfig: Record<string, unknown> = {};
  try {
    if (layerConfigJson) {
      layerConfig = JSON.parse(layerConfigJson);
    }
  } catch {
    // Invalid JSON — use empty config
  }

  const maxzoom = (layerConfig as { zoom_max?: number }).zoom_max;
  const body = (layerConfig as { body?: Record<string, unknown> }).body || {};
  const source = body.source || (layerConfig as { source?: unknown }).source;
  const styles: Record<string, unknown> = (body.styles as Record<string, unknown> | undefined) ?? {};
  const options: Record<string, unknown> = (body.options as Record<string, unknown> | undefined) ?? {};

  switch (provider) {
    case 'xyz tileset':
      return {
        type: 'tileLayer',
        body: {
          ...body,
          url: (body.url as string) || (layerConfig.url as string),
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

    case 'esri':
      return {
        body: {
          url: (body.url as string) || (layerConfig.url as string),
          params: (body.params as Record<string, unknown>) || {},
        },
      };

    case 'wms':
      return {
        body: {
          url: (body.url as string) || (layerConfig.url as string),
          params: (body.params as Record<string, unknown>) || {},
        },
      };

    case 'wmts':
      return {
        ...layerConfig,
        body: { ...body },
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
  layerConfigJson: string,
): LayerSpec | null {
  const layerConfig = buildLayerConfig(provider, layerConfigJson);
  if (!layerConfig) return null;

  const mappedProvider = PROVIDER_MAP[provider];
  if (!mappedProvider) return null;

  return {
    id: 'admin-preview',
    slug: 'admin-preview',
    type: provider,
    provider: mappedProvider,
    layerConfig,
    opacity: 1,
    visibility: true,
  };
}

// ─── Preview message payload ──────────────────────────────────────────────────

interface LayerPreviewMessage {
  type: 'LAYER_PREVIEW';
  provider: string;
  layer_config: string;
}

// ─── Page component ───────────────────────────────────────────────────────────

const LayerPreviewPage: NextPageWithLayout = () => {
  const [layerSpec, setLayerSpec] = useState<LayerSpec | null>(null);
  const [status, setStatus] = useState<'waiting' | 'ready' | 'error'>('waiting');
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [adminOrigin, setAdminOrigin] = useState<string | null>(null);

  const applyPreviewMessage = useCallback((msg: LayerPreviewMessage) => {
    const { provider, layer_config = '' } = msg;
    setErrorMsg(null);

    if (!provider) {
      setStatus('error');
      setErrorMsg('No layer provider specified.');
      return;
    }

    const spec = buildLayerSpec(provider, layer_config);
    if (!spec) {
      setStatus('error');
      setErrorMsg(`Unsupported layer provider: "${provider}"`);
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

  // Read URL query params on mount: adminOrigin for postMessage security,
  // and ?data= for immediate layer preview (avoids postMessage race condition).
  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const origin = params.get('adminOrigin');
    if (origin) setAdminOrigin(decodeURIComponent(origin));

    const data = params.get('data');
    if (data) {
      try {
        const msg = JSON.parse(atob(data));
        if (msg?.type === 'LAYER_PREVIEW') {
          applyPreviewMessage(msg as LayerPreviewMessage);
        }
      } catch {
        // Ignore invalid base64 / JSON in URL
      }
    }
  }, [applyPreviewMessage]);

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

      <OLMap
        basemap={basemapConfig}
        mapOptions={{ zoom: 2, center: { lat: 20, lng: 0 }, minZoom: 2, maxZoom: 18 }}
      >
        {(map) =>
          layerSpec && LayerManager && Layer && PluginOpenLayers ? (
            <LayerManager map={map} plugin={PluginOpenLayers}>
              <Layer {...layerSpec} />
            </LayerManager>
          ) : null
        }
      </OLMap>
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
