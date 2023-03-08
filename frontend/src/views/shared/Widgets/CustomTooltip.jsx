import React from 'react';
import { formatNumber } from 'utilities';

export const CustomTooltip = ({ active, payload, unit }) => {
  if (active) {
    return (
      <div className="m-graph__tooltip">
        {formatNumber({
          value: payload[0].payload.count,
          minimumFractionDigits: 1,
          maximumFractionDigits: 1,
        })}
        &nbsp;
        {unit}
      </div>
    );
  }
  return null;
};
