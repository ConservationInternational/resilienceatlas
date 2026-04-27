import React, { useMemo, useState, useCallback, useRef, useEffect } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { T } from '@transifex/react';
import { List } from 'react-window';

import { setHighlight, getHighlight, fetchGeometryBounds } from 'state/modules/scope_datasets';
import CategoryBadge from './CategoryBadge';

const ROW_HEIGHT = 32;
const LIST_HEIGHT = 368;
const COL_MIN_WIDTH = 130;

const DataRow = ({
  index,
  style,
  sortedData,
  unitIdColumn,
  highlight,
  datasetSlug,
  handleRowClick,
  columns,
  gridTemplate,
  formatValue,
}) => {
  const row = sortedData[index];
  const rowId = unitIdColumn ? String(row[unitIdColumn]) : String(index);
  const isHighlighted = highlight?.datasetSlug === datasetSlug && highlight?.unitId === rowId;

  return (
    <div
      style={{ ...style, display: 'grid', gridTemplateColumns: gridTemplate }}
      className={`scope-data-table__row${isHighlighted ? ' scope-data-table__row--highlighted' : ''}${unitIdColumn ? ' scope-data-table__row--clickable' : ''}`}
      onClick={() => handleRowClick(row)}
      data-unit-id={rowId}
      role="row"
    >
      {columns.map((col) => (
        <div key={col.name} className="scope-data-table__td" role="cell">
          {formatValue(row[col.name], col)}
        </div>
      ))}
    </div>
  );
};

const ScopeDataTable = ({ config, data, schema, datasetSlug }) => {
  const dispatch = useDispatch();
  const highlight = useSelector(getHighlight);
  const [sortKey, setSortKey] = useState(null);
  const [sortDir, setSortDir] = useState('asc');
  const [filterCategory, setFilterCategory] = useState(null);

  const columns = useMemo(() => {
    if (config?.columns) {
      // Preserve the order specified in config.columns
      return config.columns
        .map((name) => (schema || []).find((col) => col.name === name))
        .filter(Boolean);
    }
    return schema || [];
  }, [config, schema]);

  const categoryColumns = useMemo(
    () => columns.filter((col) => col.type === 'category').map((col) => col.name),
    [columns],
  );

  const categoryValues = useMemo(() => {
    if (!categoryColumns.length) return {};
    const values = {};
    categoryColumns.forEach((col) => {
      values[col] = [...new Set(data.map((row) => row[col]).filter(Boolean))];
    });
    return values;
  }, [data, categoryColumns]);

  const unitIdColumn = useMemo(() => {
    if (config?.unitIdColumn) return config.unitIdColumn;
    const idCol = (schema || []).find(
      (col) => col.type === 'integer' && (col.name.endsWith('_id') || col.name.endsWith('_code')),
    );
    return idCol?.name || null;
  }, [config, schema]);

  const filteredData = useMemo(() => {
    let result = data || [];
    if (filterCategory) {
      const [col, val] = filterCategory.split('::');
      result = result.filter((row) => row[col] === val);
    }
    return result;
  }, [data, filterCategory]);

  const sortedData = useMemo(() => {
    if (!sortKey) return filteredData;
    return [...filteredData].sort((a, b) => {
      const aVal = a[sortKey];
      const bVal = b[sortKey];
      if (aVal == null && bVal == null) return 0;
      if (aVal == null) return 1;
      if (bVal == null) return -1;
      if (typeof aVal === 'number' && typeof bVal === 'number') {
        return sortDir === 'asc' ? aVal - bVal : bVal - aVal;
      }
      const cmp = String(aVal).localeCompare(String(bVal));
      return sortDir === 'asc' ? cmp : -cmp;
    });
  }, [filteredData, sortKey, sortDir]);

  const handleSort = useCallback(
    (key) => {
      if (sortKey === key) {
        setSortDir((d) => (d === 'asc' ? 'desc' : 'asc'));
      } else {
        setSortKey(key);
        setSortDir('asc');
      }
    },
    [sortKey],
  );

  const handleRowClick = useCallback(
    (row) => {
      if (!unitIdColumn) return;
      const unitId = row[unitIdColumn];
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
    [dispatch, datasetSlug, unitIdColumn, highlight],
  );

  const formatValue = useCallback((value, col) => {
    if (value == null) return '—';
    if (col.type === 'number' && typeof value === 'number') {
      if (col.format?.includes(',')) {
        return value.toLocaleString(undefined, { maximumFractionDigits: 1 });
      }
      return value.toFixed(1);
    }
    if (col.type === 'category') {
      return <CategoryBadge value={value} />;
    }
    if (col.type === 'boolean') {
      return value ? '✓' : '✗';
    }
    return String(value);
  }, []);

  const handleExportCsv = useCallback(() => {
    const header = columns.map((c) => c.label || c.name).join(',');
    const rows = sortedData.map((row) =>
      columns
        .map((c) => {
          const val = row[c.name];
          if (val == null) return '';
          if (typeof val === 'string' && (val.includes(',') || val.includes('"'))) {
            return `"${val.replace(/"/g, '""')}"`;
          }
          return val;
        })
        .join(','),
    );
    const csv = [header, ...rows].join('\n');
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `${datasetSlug}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  }, [columns, sortedData, datasetSlug]);

  const listRef = useRef(null);

  const gridTemplate = useMemo(
    () => columns.map(() => `minmax(${COL_MIN_WIDTH}px, 1fr)`).join(' '),
    [columns],
  );

  const tableMinWidth = useMemo(() => columns.length * COL_MIN_WIDTH, [columns]);

  // Auto-scroll to highlighted row
  useEffect(() => {
    if (highlight?.datasetSlug === datasetSlug && listRef.current?.element) {
      const idx = sortedData.findIndex((row) => {
        const rowId = unitIdColumn ? String(row[unitIdColumn]) : null;
        return rowId === highlight.unitId;
      });
      if (idx >= 0) listRef.current.scrollToRow({ index: idx, align: 'auto' });
    }
  }, [highlight, sortedData, datasetSlug, unitIdColumn]);

  if (!columns.length || !data?.length) return null;

  return (
    <div className="scope-data-table">
      <div className="scope-data-table__controls">
        {Object.entries(categoryValues).map(([col, values]) => (
          <select
            key={col}
            className="scope-data-table__filter"
            value={filterCategory || ''}
            onChange={(e) => setFilterCategory(e.target.value || null)}
          >
            <option value="">All {(schema || []).find((c) => c.name === col)?.label || col}</option>
            {values.map((val) => (
              <option key={val} value={`${col}::${val}`}>
                {val}
              </option>
            ))}
          </select>
        ))}
        <button
          type="button"
          className="btn -secondary scope-data-table__export"
          onClick={handleExportCsv}
        >
          <T _str="Download CSV" />
        </button>
      </div>

      <div className="scope-data-table__wrapper">
        <div style={{ minWidth: tableMinWidth }}>
          <div
            className="scope-data-table__header"
            style={{ display: 'grid', gridTemplateColumns: gridTemplate }}
            role="row"
          >
            {columns.map((col) => (
              <div
                key={col.name}
                className="scope-data-table__th"
                onClick={() => handleSort(col.name)}
                style={{ cursor: 'pointer' }}
                role="columnheader"
              >
                {col.label || col.name}
                {sortKey === col.name && (
                  <span className="scope-data-table__sort-indicator">
                    {sortDir === 'asc' ? ' ▲' : ' ▼'}
                  </span>
                )}
              </div>
            ))}
          </div>
          <List
            listRef={listRef}
            style={{ height: LIST_HEIGHT, overflow: 'hidden auto' }}
            rowCount={sortedData.length}
            rowHeight={ROW_HEIGHT}
            rowComponent={DataRow}
            rowProps={{
              sortedData,
              unitIdColumn,
              highlight,
              datasetSlug,
              handleRowClick,
              columns,
              gridTemplate,
              formatValue,
            }}
          />
        </div>
      </div>

      <div className="scope-data-table__footer">
        <T _str="{count} rows" count={sortedData.length} />
      </div>
    </div>
  );
};

export default ScopeDataTable;
