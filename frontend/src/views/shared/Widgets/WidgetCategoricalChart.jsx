import dynamic from 'next/dynamic';
import React, { useMemo } from 'react';
import { ResponsiveContainer, BarChart, XAxis, YAxis, Bar, Rectangle, Tooltip } from 'recharts';
import InfoWindow from 'views/components/InfoWindow';
import { T } from '@transifex/react';

import { useWidget, formatNumber } from 'utilities';
import { CustomTooltip } from './CustomTooltip';
import DownloadCsv from './DownloadCsv';

const DownloadImageNoSSR = dynamic(() => import('./DownloadImage'), { ssr: false });

const RECTANGLE_PADDING = 4;

const CustomBar = (props) => {
  const {
    color,
    y,
    height: barHeight,
    payload: { name },
    chartWidth,
  } = props;
  return (
    <g>
      <foreignObject y={y} width={chartWidth} height={16}>
        <div className="categorical-labels with-ellipsis">{name}</div>
      </foreignObject>
      <Rectangle
        {...props}
        fill={color}
        y={y + barHeight / 2 + RECTANGLE_PADDING}
        height={barHeight - barHeight / 2}
      />
      ;
    </g>
  );
};
const BAR_HEIGHT = 30;
const CHART_MARGIN_BOTTOM = 30;

export const WidgetCategoricalChart = ({
  responsive,
  name,
  slug,
  analysisQuery,
  analysisBody,
  shortMeta,
  info,
  legend,
  geojson,
  type,
}) => {
  const { rootWidgetProps, loaded, data, noData } = useWidget(
    { slug, geojson },
    { type, analysisQuery, analysisBody, isCategorical: true },
  );

  const { unit, data: legendData } = useMemo(() => JSON.parse(legend), [legend]);
  const mergedBarData = useMemo(() => {
    return data?.rows
      ?.map((d) => {
        const legendItem = legendData.find((l) => l.mappingValue === d.mappingValue);
        return { count: d.count, color: legendItem?.value, name: legendItem?.name };
      })
      .sort((a, b) => b.count - a.count);
  }, [data, legendData]);
  const downloadData = useMemo(() => {
    return {
      fields: ['name', 'count'],
      rows: mergedBarData?.map((d) => ({ name: d.name, count: d.count })),
    };
  }, [mergedBarData]);

  const height = useMemo(() => mergedBarData?.length * BAR_HEIGHT + 50, [mergedBarData]);
  const width = responsive ? 670 : 400;

  return (
    <div {...rootWidgetProps()}>
      <div className="name">{name}</div>
      {loaded &&
        (noData ? (
          <div className="widget-no-data">
            <h3>
              <T _str="NO DATA AVAILABLE" />
            </h3>
          </div>
        ) : (
          <>
            <h4>
              <T _str="PIXELS COUNTS BY CATEGORY" />
            </h4>
            <div className="categories">
              <T _str="CATEGORIES" />
            </div>
            <ResponsiveContainer width={width} height={height}>
              <BarChart
                layout="vertical"
                data={mergedBarData}
                margin={{ bottom: CHART_MARGIN_BOTTOM }}
              >
                <XAxis
                  dataKey="count"
                  type="number"
                  interval={0}
                  label={() => (
                    <text
                      x={-5}
                      y={height + 10 - CHART_MARGIN_BOTTOM}
                      className="categorical-x-axis-label"
                    >
                      <T _str="(No. of pixels)" />
                    </text>
                  )}
                />
                <YAxis
                  dataKey="name"
                  interval={0}
                  axisLine={false}
                  type="category"
                  mirror
                  tick={false}
                  tickLine={false}
                />

                <Tooltip content={<CustomTooltip unit={unit} minimumFractionDigits={0} />} />
                <Bar dataKey="count" unit={unit} shape={<CustomBar chartWidth={width} />} />
              </BarChart>
            </ResponsiveContainer>

            {data.stats && (
              <ul className="m-widget__stats">
                <li className="stats-item">
                  <span className="stats-item__label">
                    <T _str="Max:" _comment="Max number on the widget bar chart" />{' '}
                  </span>
                  {formatNumber({ value: data.stats.max })}&nbsp;
                  {unit}
                </li>
                <li className="stats-item">
                  <span className="stats-item__label">
                    <T _str="Min:" _comment="Min number on the widget bar chart" />{' '}
                  </span>
                  {formatNumber({ value: data.stats.min })}&nbsp;
                  {unit}
                </li>
                <li className="stats-item">
                  <span className="stats-item__label">
                    <T _str="Std. deviation:" _comment="Std. deviation: on the widget bar chart" />{' '}
                  </span>
                  {formatNumber({ value: data.stats.std })}&nbsp;
                  {unit}
                </li>
                <li className="stats-item">
                  <span className="stats-item__label">
                    <T _str="Sum:" _comment="Sum: on the widget bar chart" />{' '}
                  </span>
                  {formatNumber({ value: data.stats.sum })}&nbsp;
                  {unit}
                </li>
              </ul>
            )}

            {shortMeta && (
              <div className="meta-short">
                {shortMeta}
                {!noData && <DownloadCsv data={downloadData} name={slug} />}
                {analysisBody && (
                  <DownloadImageNoSSR analysisBody={analysisBody} geojson={geojson} />
                )}
                {info && (
                  <button
                    type="button"
                    className="btn-analysis btn-analysis__info"
                    data-info={info}
                    data-name={name}
                    title={<T _str="View detailed info" />}
                    onClick={() => InfoWindow.show(name, info)}
                  >
                    <svg className="icon icon-info">
                      <use xlinkHref="#icon-info" />
                    </svg>
                  </button>
                )}
              </div>
            )}
          </>
        ))}
    </div>
  );
};

WidgetCategoricalChart.defaultProps = {
  widgetName: '',
};
