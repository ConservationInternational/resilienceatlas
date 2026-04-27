import React, { useMemo, useCallback, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import {
  ResponsiveContainer,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  PieChart,
  Pie,
  Cell,
  ScatterChart,
  Scatter,
  ZAxis,
  Legend,
} from 'recharts';

import { setHighlight, getHighlight, fetchGeometryBounds } from 'state/modules/scope_datasets';

const DEFAULT_COLORS = ['#2ecc71', '#f39c12', '#e74c3c', '#3498db', '#9b59b6', '#1abc9c'];

// Case-insensitive lookup against a color map (API lowercases keys but data values keep original case)
const lookupColor = (colorMap, key) => {
  if (!colorMap || key == null) return undefined;
  return colorMap[key] || colorMap[String(key).toLowerCase()];
};

const ScopeChart = ({ config, data, schema, datasetSlug }) => {
  const dispatch = useDispatch();
  const highlight = useSelector(getHighlight);

  const handleClick = useCallback(
    (entry) => {
      if (!config.unitIdColumn || !entry) return;
      // Recharts onClick wraps the original data row in .payload
      const row = entry.payload || entry;
      const unitId = row[config.unitIdColumn];
      if (unitId != null) {
        const unitIdStr = String(unitId);
        dispatch(setHighlight(datasetSlug, unitIdStr));
        // Fetch bounds to zoom the map (toggle-off is handled by the reducer)
        const isAlreadyHighlighted =
          highlight?.datasetSlug === datasetSlug && highlight?.unitId === unitIdStr;
        if (!isAlreadyHighlighted) {
          dispatch(fetchGeometryBounds(datasetSlug, unitIdStr));
        }
      }
    },
    [dispatch, datasetSlug, config.unitIdColumn, highlight],
  );

  switch (config.type) {
    case 'horizontalBar':
      return (
        <HorizontalBarChart
          config={config}
          data={data}
          highlight={highlight}
          datasetSlug={datasetSlug}
          onClick={handleClick}
        />
      );
    case 'donut':
    case 'pie':
      return <DonutChart config={config} data={data} />;
    case 'scatter':
      return (
        <ScatterPlot
          config={config}
          data={data}
          schema={schema}
          highlight={highlight}
          datasetSlug={datasetSlug}
          onClick={handleClick}
        />
      );
    case 'groupedBar':
      return <GroupedBarChart config={config} data={data} />;
    case 'columnsDonut':
      return <ColumnsDonutChart config={config} data={data} />;
    default:
      return null;
  }
};

const ChartWrapper = ({ title, description, methodologyNote, children }) => {
  const [noteOpen, setNoteOpen] = useState(false);
  return (
    <div className="scope-chart">
      {title && (
        <div className="scope-chart__title-row">
          <h5 className="scope-chart__title">{title}</h5>
          {methodologyNote && (
            <button
              className={`scope-chart__info-btn${noteOpen ? ' scope-chart__info-btn--active' : ''}`}
              onClick={() => setNoteOpen((v) => !v)}
              title="How this was calculated"
              aria-expanded={noteOpen}
              type="button"
            >
              ⓘ
            </button>
          )}
        </div>
      )}
      {noteOpen && methodologyNote && (
        <div className="scope-chart__methodology-note">{methodologyNote}</div>
      )}
      {description && <p className="scope-chart__description">{description}</p>}
      <div className="scope-chart__container">{children}</div>
    </div>
  );
};

const HorizontalBarChart = ({ config, data, highlight, datasetSlug, onClick }) => {
  const { xAxis, yAxis, colorBy, sortBy, topN, bottomN } = config;

  const chartData = useMemo(() => {
    let sorted = [...data];
    if (sortBy) {
      sorted.sort((a, b) => {
        const diff = (Number(a[sortBy.key]) || 0) - (Number(b[sortBy.key]) || 0);
        return sortBy.order === 'desc' ? -diff : diff;
      });
    }
    // Slice to top N and/or bottom N if configured
    if ((topN || bottomN) && sorted.length > (topN || 0) + (bottomN || 0)) {
      const top = topN ? sorted.slice(0, topN) : [];
      const bottom = bottomN ? sorted.slice(-bottomN) : [];
      sorted = [...top, ...bottom];
    }
    const barKey = xAxis?.key || 'value';
    return sorted.map((row) => ({
      ...row,
      [barKey]: Number(row[barKey]) || 0,
      _label: row[yAxis.key] || row[yAxis.fallback] || '',
    }));
  }, [data, sortBy, yAxis, topN, bottomN, xAxis]);

  const getBarColor = useCallback(
    (entry) => {
      if (colorBy?.colors && entry[colorBy.key]) {
        return lookupColor(colorBy.colors, entry[colorBy.key]) || DEFAULT_COLORS[0];
      }
      return DEFAULT_COLORS[0];
    },
    [colorBy],
  );

  const maxHeight = Math.max(400, chartData.length * 24);

  return (
    <ChartWrapper title={config.title} description={config.description} methodologyNote={config.methodology_note}>
      <ResponsiveContainer width="100%" height={maxHeight}>
        <BarChart
          data={chartData}
          layout="vertical"
          margin={{ left: 20, right: 10, top: 5, bottom: 5 }}
        >
          <CartesianGrid strokeDasharray="3 3" />
          <XAxis type="number" tick={{ fontSize: 10 }} />
          <YAxis dataKey="_label" type="category" width={140} tick={{ fontSize: 9 }} />
          <Tooltip />
          <Bar dataKey={xAxis?.key || 'value'} onClick={(d) => onClick(d)}>
            {chartData.map((entry, idx) => {
              const isHighlighted =
                highlight?.datasetSlug === datasetSlug &&
                config.unitIdColumn &&
                String(entry[config.unitIdColumn]) === highlight?.unitId;
              return (
                <Cell
                  key={idx}
                  fill={getBarColor(entry)}
                  opacity={isHighlighted ? 1 : highlight ? 0.4 : 0.85}
                  stroke={isHighlighted ? '#000' : 'none'}
                  strokeWidth={isHighlighted ? 2 : 0}
                  cursor="pointer"
                />
              );
            })}
          </Bar>
        </BarChart>
      </ResponsiveContainer>
    </ChartWrapper>
  );
};

const DonutChart = ({ config, data }) => {
  const { valueKey, categoryKey, colors, aggregation, tooltipUnit } = config;

  const pieData = useMemo(() => {
    const grouped = {};
    data.forEach((row) => {
      const cat = row[categoryKey] || 'Unknown';
      if (!grouped[cat]) grouped[cat] = 0;
      if (aggregation === 'sum') {
        grouped[cat] += Number(row[valueKey]) || 0;
      } else {
        grouped[cat] += 1;
      }
    });
    return Object.entries(grouped).map(([name, value]) => ({
      name,
      value: Math.round(value * 100) / 100,
    }));
  }, [data, valueKey, categoryKey, aggregation]);

  const total = useMemo(() => pieData.reduce((sum, d) => sum + d.value, 0), [pieData]);

  const getColor = useCallback(
    (name) =>
      lookupColor(colors, name) ||
      DEFAULT_COLORS[pieData.findIndex((d) => d.name === name) % DEFAULT_COLORS.length],
    [colors, pieData],
  );

  const renderInsideLabel = useCallback(
    ({ cx, cy, midAngle, innerRadius, outerRadius, percent }) => {
      if (percent < 0.05) return null;
      const RADIAN = Math.PI / 180;
      const radius = innerRadius + (outerRadius - innerRadius) * 0.5;
      const x = cx + radius * Math.cos(-midAngle * RADIAN);
      const y = cy + radius * Math.sin(-midAngle * RADIAN);
      return (
        <text
          x={x}
          y={y}
          fill="#fff"
          textAnchor="middle"
          dominantBaseline="central"
          fontSize={11}
          fontWeight={600}
        >
          {`${(percent * 100).toFixed(0)}%`}
        </text>
      );
    },
    [],
  );

  const renderTooltip = useCallback(
    ({ active, payload }) => {
      if (!active || !payload?.length) return null;
      const entry = payload[0];
      const pct = total > 0 ? ((entry.value / total) * 100).toFixed(1) : '0';
      const unit = tooltipUnit || '';
      return (
        <div
          style={{
            background: '#fff',
            border: '1px solid #ccc',
            borderRadius: 4,
            padding: '8px 12px',
            fontSize: 12,
            lineHeight: 1.6,
            boxShadow: '0 2px 6px rgba(0,0,0,0.15)',
          }}
        >
          <div style={{ fontWeight: 600, marginBottom: 4 }}>{entry.name}</div>
          <div>{pct}%</div>
          <div>
            {entry.value.toLocaleString()}
            {unit ? ` ${unit}` : ''}
          </div>
        </div>
      );
    },
    [total, tooltipUnit],
  );

  return (
    <ChartWrapper title={config.title} description={config.description} methodologyNote={config.methodology_note}>
      <ResponsiveContainer width="100%" height={250}>
        <PieChart>
          <Pie
            data={pieData}
            dataKey="value"
            nameKey="name"
            cx="50%"
            cy="50%"
            innerRadius={45}
            outerRadius={80}
            label={renderInsideLabel}
            labelLine={false}
          >
            {pieData.map((entry) => (
              <Cell key={entry.name} fill={getColor(entry.name)} />
            ))}
          </Pie>
          <Tooltip content={renderTooltip} />
          <Legend
            layout="horizontal"
            verticalAlign="bottom"
            align="center"
            wrapperStyle={{ fontSize: 11, paddingTop: 8 }}
            formatter={(value) => {
              const item = pieData.find((d) => d.name === value);
              const pct = total > 0 && item ? ((item.value / total) * 100).toFixed(1) : '0';
              return `${value} (${pct}%)`;
            }}
          />
        </PieChart>
      </ResponsiveContainer>
    </ChartWrapper>
  );
};

const ScatterPlot = ({ config, data, schema, onClick }) => {
  const { xAxis, yAxis, sizeKey, colorBy, labelKey } = config;

  // Build a lookup from raw field names to pretty labels
  const fieldLabels = useMemo(() => {
    const labels = {};
    (schema || []).forEach((col) => {
      labels[col.name] = col.label || col.name;
    });
    return labels;
  }, [schema]);

  const chartData = useMemo(() => {
    return data.map((row) => ({
      ...row,
      _x: Number(row[xAxis?.key]) || 0,
      _y: Number(row[yAxis?.key]) || 0,
      _size: Number(row[sizeKey]) || 100,
      _label: row[labelKey] || row[config.unitIdColumn] || '',
      _category: row[colorBy?.key] || '',
    }));
  }, [data, xAxis, yAxis, sizeKey, colorBy, labelKey, config.unitIdColumn]);

  const categories = useMemo(() => {
    const cats = [...new Set(chartData.map((d) => d._category))];
    return cats.filter(Boolean);
  }, [chartData]);

  const prettyLabel = useCallback((key) => fieldLabels[key] || key, [fieldLabels]);

  const renderTooltip = useCallback(
    ({ active, payload }) => {
      if (!active || !payload?.length) return null;
      const entry = payload[0]?.payload;
      if (!entry) return null;
      return (
        <div
          style={{
            background: '#fff',
            border: '1px solid #ccc',
            borderRadius: 4,
            padding: '8px 12px',
            fontSize: 12,
            lineHeight: 1.6,
            boxShadow: '0 2px 6px rgba(0,0,0,0.15)',
          }}
        >
          {entry._label && <div style={{ fontWeight: 600, marginBottom: 4 }}>{entry._label}</div>}
          <div>
            {xAxis?.label || prettyLabel(xAxis?.key)}:{' '}
            {typeof entry._x === 'number' ? entry._x.toLocaleString() : entry._x}
          </div>
          <div>
            {yAxis?.label || prettyLabel(yAxis?.key)}:{' '}
            {typeof entry._y === 'number' ? entry._y.toLocaleString() : entry._y}
          </div>
          {sizeKey && (
            <div>
              {prettyLabel(sizeKey)}:{' '}
              {typeof entry._size === 'number' ? entry._size.toLocaleString() : entry._size}
            </div>
          )}
          {entry._category && (
            <div>
              {prettyLabel(colorBy?.key)}: {entry._category}
            </div>
          )}
        </div>
      );
    },
    [xAxis, yAxis, sizeKey, colorBy, prettyLabel],
  );

  return (
    <ChartWrapper title={config.title} description={config.description} methodologyNote={config.methodology_note}>
      <ResponsiveContainer width="100%" height={300}>
        <ScatterChart margin={{ top: 10, right: 10, bottom: 30, left: 10 }}>
          <CartesianGrid strokeDasharray="3 3" />
          <XAxis
            dataKey="_x"
            type="number"
            name={xAxis?.label}
            label={{ value: xAxis?.label, position: 'bottom', offset: 0, fontSize: 11 }}
            tick={{ fontSize: 10 }}
          />
          <YAxis
            dataKey="_y"
            type="number"
            name={yAxis?.label}
            label={{ value: yAxis?.label, angle: -90, position: 'left', fontSize: 11 }}
            tick={{ fontSize: 10 }}
            width={50}
          />
          <ZAxis dataKey="_size" range={[20, 200]} />
          <Tooltip cursor={{ strokeDasharray: '3 3' }} content={renderTooltip} />
          <Legend wrapperStyle={{ fontSize: 11, paddingTop: 4 }} />
          {categories.map((cat) => (
            <Scatter
              key={cat}
              name={cat}
              data={chartData.filter((d) => d._category === cat)}
              fill={
                lookupColor(colorBy?.colors, cat) ||
                DEFAULT_COLORS[categories.indexOf(cat) % DEFAULT_COLORS.length]
              }
              onClick={(d) => onClick(d)}
              cursor="pointer"
            />
          ))}
        </ScatterChart>
      </ResponsiveContainer>
    </ChartWrapper>
  );
};

const GroupedBarChart = ({ config, data }) => {
  const { groupKey, bars, aggregation } = config;

  const chartData = useMemo(() => {
    const grouped = {};
    data.forEach((row) => {
      const group = row[groupKey] || 'Unknown';
      if (!grouped[group]) {
        grouped[group] = { _group: group };
        (bars || []).forEach((b) => {
          grouped[group][b.key] = 0;
        });
      }
      (bars || []).forEach((b) => {
        if (aggregation === 'sum') {
          grouped[group][b.key] += row[b.key] || 0;
        }
      });
    });
    return Object.values(grouped).map((g) => {
      const rounded = { ...g };
      (bars || []).forEach((b) => {
        rounded[b.key] = Math.round(rounded[b.key] * 100) / 100;
      });
      return rounded;
    });
  }, [data, groupKey, bars, aggregation]);

  return (
    <ChartWrapper title={config.title} description={config.description} methodologyNote={config.methodology_note}>
      <ResponsiveContainer width="100%" height={300}>
        <BarChart data={chartData} margin={{ left: 20, right: 20, top: 5, bottom: 5 }}>
          <CartesianGrid strokeDasharray="3 3" />
          <XAxis dataKey="_group" />
          <YAxis />
          <Tooltip formatter={(value) => value.toLocaleString()} />
          <Legend />
          {(bars || []).map((b) => (
            <Bar key={b.key} dataKey={b.key} name={b.label} fill={b.color || DEFAULT_COLORS[0]} />
          ))}
        </BarChart>
      </ResponsiveContainer>
    </ChartWrapper>
  );
};

/**
 * ColumnsDonutChart — sums named columns across all rows and shows each as a
 * donut segment.  Used for multi-column breakdowns like the 7-class SDG 15.3.1
 * status transition or the 3-class baseline condition.
 *
 * Config shape:
 *   columns: [{ key, label, color }]
 *   aggregation: "sum" (default)
 */
const ColumnsDonutChart = ({ config, data }) => {
  const { columns = [] } = config;

  const pieData = useMemo(() => {
    return columns.map((col) => {
      const total = data.reduce((sum, row) => sum + (Number(row[col.key]) || 0), 0);
      return { name: col.label || col.key, value: Math.round(total * 100) / 100, color: col.color };
    });
  }, [data, columns]);

  const renderInsideLabel = useCallback(
    ({ cx, cy, midAngle, innerRadius, outerRadius, percent }) => {
      if (percent < 0.04) return null;
      const RADIAN = Math.PI / 180;
      const radius = innerRadius + (outerRadius - innerRadius) * 0.5;
      const x = cx + radius * Math.cos(-midAngle * RADIAN);
      const y = cy + radius * Math.sin(-midAngle * RADIAN);
      return (
        <text
          x={x}
          y={y}
          fill="#333"
          textAnchor="middle"
          dominantBaseline="central"
          fontSize={11}
          fontWeight={600}
        >
          {`${(percent * 100).toFixed(0)}%`}
        </text>
      );
    },
    [],
  );

  return (
    <ChartWrapper title={config.title} description={config.description} methodologyNote={config.methodology_note}>
      <ResponsiveContainer width="100%" height={280}>
        <PieChart>
          <Pie
            data={pieData}
            dataKey="value"
            nameKey="name"
            cx="50%"
            cy="50%"
            innerRadius={45}
            outerRadius={80}
            label={renderInsideLabel}
            labelLine={false}
          >
            {pieData.map((entry) => (
              <Cell key={entry.name} fill={entry.color || DEFAULT_COLORS[0]} />
            ))}
          </Pie>
          <Tooltip formatter={(value) => value.toLocaleString()} />
          <Legend
            layout="horizontal"
            verticalAlign="bottom"
            align="center"
            wrapperStyle={{ fontSize: 11, paddingTop: 8 }}
            formatter={(value) => {
              const item = pieData.find((d) => d.name === value);
              const total = pieData.reduce((sum, d) => sum + d.value, 0);
              const pct = total > 0 && item ? ((item.value / total) * 100).toFixed(1) : '0';
              return `${value} (${pct}%)`;
            }}
          />
        </PieChart>
      </ResponsiveContainer>
    </ChartWrapper>
  );
};

export default ScopeChart;
