import React, { useState, useEffect, useCallback } from 'react';
import PropTypes from 'prop-types';
import { connect } from 'react-redux';
import { useT } from '@transifex/react';
import {
  AreaChart,
  Area,
  CartesianGrid,
  Label,
  ReferenceArea,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';

import { setChartLimit } from 'state/modules/layers';

const LegendChart = ({
  data,
  bucket = [],
  limit = 100,
  metadata: { xLabel, yLabel },
  changeLimit,
}) => {
  const t = useT();
  const [isReady, setIsReady] = useState(false);
  const [activeCoordinate, setActiveCoordinate] = useState(null);

  useEffect(() => {
    // Ok, I'm not very proud of this, but it works... WHY?!!!!
    const timer = setTimeout(() => {
      setIsReady(true);
      setActiveCoordinate(data.find((v) => v.x === limit));
    }, 100);
    return () => clearTimeout(timer);
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  const changeReferenceArea = useCallback(
    (p) => {
      if (!p?.activePayload?.length) return;
      setActiveCoordinate(p.activePayload[0].payload);
      changeLimit(p);
    },
    [changeLimit],
  );

  const len = data.length;
  const min = data[0];
  const mid = data[Math.round(len / 2) - 1];
  const max = data[len - 1];

  return (
    <div className="m-legend__chart">
      {isReady && (
        <ResponsiveContainer width="100%" height={250} debounce={160}>
          <AreaChart
            data={data}
            margin={{ top: 30, right: 5, left: 10, bottom: 10 }}
            onClick={changeReferenceArea}
          >
            <defs>
              <linearGradient id="colorX" x1="0" y1="0" x2="0" y2="1">
                {(bucket || []).map((color, i) => (
                  <stop
                    key={`${color}_${i}`}
                    offset={`${(100 / (bucket || []).length) * i}%`}
                    stopColor={color}
                    stopOpacity={1}
                  />
                ))}
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis
              dataKey="x"
              ticks={[min.x, mid.x, max.x]}
              interval="preserveStartEnd"
              fontSize={10}
            >
              <Label
                value={t('Proportion of area protected', {
                  comment: 'X-axis label on SPARC priority chart',
                })}
                offset={-200}
                position="insideTop"
                fontSize={9}
                style={{ textTransform: 'uppercase' }}
              />
            </XAxis>
            <YAxis
              width={40}
              dataKey="y"
              ticks={[min.y, mid.y, max.y]}
              fontSize={10}
              label={{
                value: t('Proportion of carbon storage saved', {
                  comment: 'Y-axis label on SPARC priority chart',
                }),
                angle: -90,
                position: 'insideBottomLeft',
                fontSize: 9,
                offset: 0,
                style: { textTransform: 'uppercase' },
              }}
            />
            <Area
              type="monotone"
              dataKey="y"
              stroke="#8884d8"
              fill="url(#colorX)"
              fillOpacity={1}
              activeDot={{ r: 3, stroke: '#8884d8' }}
            />
            <Tooltip
              formatter={(value) => [yLabel.replace('{{value}}', value), 'Y']}
              labelFormatter={(value) => `X : ${xLabel.replace('{{value}}', value)}`}
            />
            <ReferenceArea
              x1={min.x}
              x2={limit}
              y1={min.y}
              y2={activeCoordinate ? activeCoordinate.y : max.y}
              stroke="red"
              strokeOpacity={0.3}
            >
              <Label
                value={activeCoordinate ? activeCoordinate.y : max.y}
                style={{ fontSize: 10 }}
                position={limit > 20 ? 'insideTop' : 'top'}
              />
              <Label
                value={limit}
                style={{ fontSize: 10 }}
                position={limit > 20 ? 'insideRight' : 'right'}
              />
            </ReferenceArea>
          </AreaChart>
        </ResponsiveContainer>
      )}
    </div>
  );
};

LegendChart.defaultProps = {
  bucket: [],
  limit: 100,
};

LegendChart.propTypes = {
  data: PropTypes.arrayOf(
    PropTypes.shape({
      x: PropTypes.number.isRequired,
      y: PropTypes.number.isRequired,
    }),
  ).isRequired,
  bucket: PropTypes.arrayOf(PropTypes.string),
  limit: PropTypes.number,
  metadata: PropTypes.shape({
    xLabel: PropTypes.string.isRequired,
    yLabel: PropTypes.string.isRequired,
  }).isRequired,
  changeLimit: PropTypes.func.isRequired,
};

const mapDispatchToProps = (dispatch, { layerId }) => ({
  changeLimit: (value) => {
    if (value && value.activeTooltipIndex)
      dispatch(setChartLimit(layerId, value.activeTooltipIndex));
  },
});

export default connect(null, mapDispatchToProps)(LegendChart);
