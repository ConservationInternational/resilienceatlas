import React from 'react';
import { formatNumber } from 'utilities';

export const CustomTooltip = ({ active, payload, unit, minimumFractionDigits }) => {
  if (active) {
    return (
      <div className="m-graph__tooltip">
        {formatNumber({
          value: payload[0].payload.count,
          minimumFractionDigits: minimumFractionDigits === 0 ? 0 : minimumFractionDigits || 1,
          maximumFractionDigits: 1,
        })}
        &nbsp;
        {unit}
      </div>
    );
  }
  return null;
};
