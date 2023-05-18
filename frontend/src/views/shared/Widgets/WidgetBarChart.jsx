import dynamic from 'next/dynamic';
import React, { useMemo } from 'react';
import { ResponsiveContainer, BarChart, XAxis, YAxis, CartesianGrid, Bar, Tooltip } from 'recharts';

import InfoWindow from 'views/components/InfoWindow';
import { T } from '@transifex/react';

import { useWidget, formatNumber } from 'utilities';
import { CustomTooltip } from './CustomTooltip';
import DownloadCsv from './DownloadCsv';

const DownloadImageNoSSR = dynamic(() => import('./DownloadImage'), { ssr: false });

const tickOptions = { fill: '#999', fontSize: 14 };

export const WidgetBarChart = ({
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
    { type, analysisQuery, analysisBody },
  );
  const { unit, bar_color } = useMemo(() => JSON.parse(legend), [legend]);
  const isCOG = useMemo(() => type === 'cog', [type]);

  const mergedBarData = useMemo(() => {
    return isCOG
      ? data?.rows
          ?.map((d) => {
            return { count: d.count, min: d.mappingValue };
          })
          .sort((a, b) => a.min - b.min)
      : data?.rows;
  }, [data, isCOG]);

  const downloadData = useMemo(() => {
    return isCOG
      ? {
          fields: ['name', 'count'],
          rows: mergedBarData?.map((d) => ({ name: d.name, min: d.count })),
        }
      : data;
  }, [mergedBarData, isCOG, data]);

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
            <ResponsiveContainer width={responsive ? 670 : 400} height={responsive ? 300 : 240}>
              <BarChart data={mergedBarData} margin={{ top: 40, bottom: 50 }}>
                <CartesianGrid vertical={false} strokeDasharray="2 2" />
                <XAxis
                  dataKey="min"
                  interval={0}
                  tick={{
                    ...tickOptions,
                    angle: -90,
                    dx: -6,
                  }}
                  tickFormatter={(value) =>
                    formatNumber({
                      value,
                      minimumFractionDigits: isCOG ? 0 : 1,
                      maximumFractionDigits: 1,
                    })
                  }
                  textAnchor="end"
                  tickLine={false}
                />
                <YAxis
                  allowDataOverflow
                  axisLine={false}
                  tickLine={false}
                  tickCount={10}
                  tickFormatter={(value) =>
                    formatNumber({
                      value,
                      formatFrom: 1e3,
                      maximumFractionDigits: 0,
                    })
                  }
                  unit={unit}
                  tick={{ ...tickOptions }}
                  padding={{ right: 20 }}
                />

                <Tooltip content={<CustomTooltip unit={unit} />} />
                <Bar
                  barSize={responsive ? 18 : 12}
                  dataKey="count"
                  fill={bar_color ? bar_color : '#0089CC'}
                />
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
                  {formatNumber({ value: data.stats.stdev })}&nbsp;
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

WidgetBarChart.defaultProps = {
  widgetName: '',
};
