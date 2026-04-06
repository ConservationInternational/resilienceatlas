import React, { useMemo } from 'react';

const KPISummaryCards = ({ config, data }) => {
  const cards = useMemo(() => {
    if (!config?.cards || !data?.length) return [];

    return config.cards.map((cardCfg) => {
      const { label, key, aggregation, format } = cardCfg;
      let value;

      switch (aggregation) {
        case 'sum':
          value = data.reduce((acc, row) => acc + (row[key] || 0), 0);
          break;
        case 'avg':
          value = data.reduce((acc, row) => acc + (row[key] || 0), 0) / data.length;
          break;
        case 'count':
          value = data.length;
          break;
        case 'countDistinct':
          value = new Set(data.map((row) => row[key])).size;
          break;
        case 'countWhere': {
          const { whereKey, whereValue } = cardCfg;
          value = data.filter((row) => row[whereKey] === whereValue).length;
          break;
        }
        default:
          value = data.reduce((acc, row) => acc + (row[key] || 0), 0);
      }

      let formatted;
      if (format === 'integer') {
        formatted = Math.round(value).toLocaleString();
      } else if (format === 'percent') {
        formatted = `${value.toFixed(1)}%`;
      } else if (typeof value === 'number') {
        formatted = value.toLocaleString(undefined, { maximumFractionDigits: 1 });
      } else {
        formatted = String(value);
      }

      return { label, value: formatted, color: cardCfg.color };
    });
  }, [config, data]);

  if (!cards.length) return null;

  return (
    <div className="kpi-summary-cards">
      {cards.map((card) => (
        <div
          key={card.label}
          className="kpi-summary-cards__card"
          style={card.color ? { borderTopColor: card.color } : undefined}
        >
          <div className="kpi-summary-cards__value">{card.value}</div>
          <div className="kpi-summary-cards__label">{card.label}</div>
        </div>
      ))}
    </div>
  );
};

export default KPISummaryCards;
