import React, { useEffect, useMemo, useCallback } from 'react';
import { useSelector, useDispatch } from 'react-redux';
import { T } from '@transifex/react';

import { subdomain } from 'utilities/getSubdomain';
import Loader from 'views/shared/Loader';
import {
  load,
  loadDetail,
  setActiveVariant,
  setActiveDimension,
  getLoaded,
  getLoading,
  getDatasets,
  getBySlug,
  getDetailLoading,
  getActiveVariant,
  getActiveDimension,
  getSpatialFilter,
  getFilteredData,
} from 'state/modules/scope_datasets';

import ScopeChart from './ScopeChart';
import ScopeDataTable from './ScopeDataTable';
import KPISummaryCards from './KPISummaryCards';

const ScopeStatisticsPanel = () => {
  const dispatch = useDispatch();
  const loaded = useSelector(getLoaded);
  const loading = useSelector(getLoading);
  const datasets = useSelector(getDatasets);
  const bySlug = useSelector(getBySlug);
  const detailLoading = useSelector(getDetailLoading);
  const selectedVariant = useSelector(getActiveVariant);
  const selectedDimension = useSelector(getActiveDimension);
  const spatialFilter = useSelector(getSpatialFilter);

  useEffect(() => {
    if (!loaded && !loading) {
      dispatch(load(subdomain));
    }
  }, [dispatch, loaded, loading]);

  // Collect unique dimensions across all datasets
  const dimensions = useMemo(() => {
    const seen = new Map();
    datasets.forEach((d) => {
      if (d.dimension && !seen.has(d.dimension)) {
        const cfg = d.dimension_config || {};
        seen.set(d.dimension, cfg.unitLabel || d.dimension);
      }
    });
    return [...seen.entries()].map(([value, label]) => ({ value, label }));
  }, [datasets]);

  const activeDimension = selectedDimension || (dimensions[0] && dimensions[0].value) || null;

  const handleDimensionChange = useCallback(
    (e) => {
      dispatch(setActiveDimension(e.target.value));
    },
    [dispatch],
  );

  // Group datasets by group_key, filtered to the active dimension.
  const groups = useMemo(() => {
    const map = {};
    datasets.forEach((d) => {
      // Filter by dimension if dimensions exist
      if (dimensions.length > 0 && d.dimension && d.dimension !== activeDimension) return;
      const key = d.group_key || d.slug;
      if (!map[key]) {
        map[key] = { group_key: key, variants: [], display_order: d.display_order || 0 };
      }
      map[key].variants.push(d);
    });
    return Object.values(map).sort((a, b) => a.display_order - b.display_order);
  }, [datasets, dimensions, activeDimension]);

  // Collect unique variant labels across all groups for the global selector
  const variantLabels = useMemo(() => {
    const labels = new Set();
    datasets.forEach((d) => {
      if (d.variant_label) labels.add(d.variant_label);
    });
    const preferredOrder = ['Trends.Earth', 'FAO-WOCAT', 'JRC'];
    return [...labels].sort((a, b) => {
      const ai = preferredOrder.indexOf(a);
      const bi = preferredOrder.indexOf(b);
      // Unknown labels go after known ones, sorted alphabetically
      if (ai === -1 && bi === -1) return a.localeCompare(b);
      if (ai === -1) return 1;
      if (bi === -1) return -1;
      return ai - bi;
    });
  }, [datasets]);

  const activeVariant = selectedVariant || variantLabels[0] || null;

  const handleVariantChange = useCallback(
    (e) => {
      dispatch(setActiveVariant(e.target.value));
    },
    [dispatch],
  );

  // Lazy detail loading — fetch the first visible dataset immediately,
  // then stagger remaining loads to avoid flooding the network.
  useEffect(() => {
    if (!loaded || groups.length === 0) return;

    const pending = [];
    groups.forEach((group) => {
      const dataset =
        group.variants.find((v) => v.variant_label === activeVariant) || group.variants[0];
      if (!dataset?.slug) return;
      const existing = bySlug[dataset.slug];
      if (existing && !existing.detailLoaded && !detailLoading[dataset.slug]) {
        pending.push(dataset.slug);
      }
    });

    if (pending.length === 0) return;

    // Load the first dataset immediately (it's visible at the top)
    dispatch(loadDetail(pending[0], subdomain));

    // Stagger remaining loads so we don't fire 5+ parallel requests
    const remaining = pending.slice(1);
    const handles = [];
    remaining.forEach((slug, i) => {
      if (typeof window !== 'undefined' && 'requestIdleCallback' in window) {
        handles.push(
          window.requestIdleCallback(() => dispatch(loadDetail(slug, subdomain)), {
            timeout: 2000 + i * 500,
          }),
        );
      } else {
        handles.push(setTimeout(() => dispatch(loadDetail(slug, subdomain)), 200 + i * 300));
      }
    });

    return () => {
      handles.forEach((h) => {
        if (typeof window !== 'undefined' && 'cancelIdleCallback' in window) {
          window.cancelIdleCallback(h);
        } else {
          clearTimeout(h);
        }
      });
    };
  }, [dispatch, loaded, groups, activeVariant, bySlug, detailLoading]);

  if (loading && !loaded) {
    return <Loader loading text="Loading statistics..." />;
  }

  if (loaded && datasets.length === 0) {
    return null;
  }

  return (
    <div className="scope-statistics-panel">
      <div className="scope-statistics-panel__header">
        <h3 className="scope-statistics-panel__title">
          <T _str="Statistics" />
        </h3>

        {dimensions.length > 1 && (
          <div className="scope-statistics-panel__dimension-selector">
            {dimensions.map((dim) => (
              <label key={dim.value} className="scope-statistics-panel__dimension-option">
                <input
                  type="radio"
                  name="scope-dimension"
                  value={dim.value}
                  checked={activeDimension === dim.value}
                  onChange={handleDimensionChange}
                />
                <span>{dim.label}</span>
              </label>
            ))}
          </div>
        )}

        {variantLabels.length > 1 && (
          <div className="scope-statistics-panel__variant-selector">
            <label className="scope-statistics-panel__variant-label" htmlFor="scope-variant-select">
              <T _str="Methodology" />
            </label>
            <select
              id="scope-variant-select"
              className="scope-statistics-panel__variant-select"
              value={activeVariant || ''}
              onChange={handleVariantChange}
            >
              {variantLabels.map((label) => (
                <option key={label} value={label}>
                  {label}
                </option>
              ))}
            </select>
          </div>
        )}
      </div>

      {groups.map((group) => {
        // Pick the variant matching the selector, or fall back to first
        const dataset =
          group.variants.find((v) => v.variant_label === activeVariant) || group.variants[0];
        const detail = bySlug[dataset.slug];

        if (!detail || !detail.detailLoaded) {
          return (
            <div key={group.group_key} className="scope-statistics-panel__dataset">
              <h4 className="scope-statistics-panel__dataset-title">{dataset.name}</h4>
              <Loader loading text="Loading data..." />
            </div>
          );
        }

        return (
          <ScopeDatasetSection key={detail.slug} dataset={detail} spatialFilter={spatialFilter} />
        );
      })}
    </div>
  );
};

const ScopeDatasetSection = ({ dataset, spatialFilter }) => {
  const { slug, name, description, schema_config, chart_config } = dataset;
  const charts = useMemo(() => chart_config || [], [chart_config]);
  const rows = useMemo(() => getFilteredData(dataset, spatialFilter), [dataset, spatialFilter]);

  const kpiChart = useMemo(() => charts.find((c) => c.type === 'kpi'), [charts]);
  const visualCharts = useMemo(
    () => charts.filter((c) => c.type !== 'kpi' && c.type !== 'table'),
    [charts],
  );
  const tableChart = useMemo(() => charts.find((c) => c.type === 'table'), [charts]);

  return (
    <div className="scope-statistics-panel__dataset">
      <h4 className="scope-statistics-panel__dataset-title">{name}</h4>
      {description && <p className="scope-statistics-panel__dataset-description">{description}</p>}

      {kpiChart && <KPISummaryCards config={kpiChart} data={rows} />}

      {visualCharts.map((chartCfg, idx) => (
        <ScopeChart
          key={`${slug}-${chartCfg.id || idx}`}
          config={chartCfg}
          data={rows}
          schema={schema_config}
          datasetSlug={slug}
        />
      ))}

      {tableChart ? (
        <ScopeDataTable config={tableChart} data={rows} schema={schema_config} datasetSlug={slug} />
      ) : (
        <ScopeDataTable data={rows} schema={schema_config} datasetSlug={slug} />
      )}
    </div>
  );
};

export default ScopeStatisticsPanel;
