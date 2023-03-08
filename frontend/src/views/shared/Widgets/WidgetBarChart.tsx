import type { FC } from 'react';
import React, { useMemo } from 'react';
import { ResponsiveContainer, BarChart, XAxis, YAxis, CartesianGrid, Bar, Tooltip } from 'recharts';

import InfoWindow from 'views/components/InfoWindow';

import { useWidget, formatNumber } from 'utilities';
import { CustomTooltip } from './CustomTooltip';
import DownloadCsv from './DownloadCsv';
import DownloadImage from './DownloadImage';

const tickOptions = { fill: '#999', fontSize: 14 };

interface P {
  name: string;
  slug: string;
  query: string;
  meta_short: string;
  metadata: string;
  geojson: L.GeoJSON;
}

export const WidgetBarChart: FC<P> = ({
  responsive,
  name,
  slug,
  analysisQuery,
  analysisBody,
  meta_short,
  metadata,
  legend,
  geojson,
}) => {
  const { rootWidgetProps, loaded, data, noData } = useWidget(
    { slug, geojson },
    { analysisQuery, analysisBody },
  );

  const { unit, bar_color } = useMemo(() => JSON.parse(legend), [legend]);

  return (
    <div {...rootWidgetProps()}>
      <div className="name">{name}</div>
      {loaded &&
        (noData ? (
          <div className="widget-no-data">
            <h3>NO DATA AVAILABLE</h3>
          </div>
        ) : (
          <>
            <ResponsiveContainer width={responsive ? 670 : 400} height={responsive ? 300 : 240}>
              <BarChart data={data.rows} margin={{ top: 40, bottom: 50 }}>
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
                      minimumFractionDigits: 1,
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
                  <span className="stats-item__label">Max: </span>
                  {formatNumber({ value: data.stats.max })}&nbsp;
                  {unit}
                </li>
                <li className="stats-item">
                  <span className="stats-item__label">Min: </span>
                  {formatNumber({ value: data.stats.min })}&nbsp;
                  {unit}
                </li>
                <li className="stats-item">
                  <span className="stats-item__label">Std. deviation: </span>
                  {formatNumber({ value: data.stats.stdev })}&nbsp;
                  {unit}
                </li>
                <li className="stats-item">
                  <span className="stats-item__label">Sum: </span>
                  {formatNumber({ value: data.stats.sum })}&nbsp;
                  {unit}
                </li>
              </ul>
            )}

            {meta_short && (
              <div className="meta-short">
                {meta_short}

                {!noData && <DownloadCsv data={data} name={slug} />}

                {analysisBody && <DownloadImage analysisBody={analysisBody} geojson={geojson} />}

                {metadata && (
                  <button
                    type="button"
                    className="btn-analysis btn-analysis__info"
                    data-info={metadata}
                    data-name={name}
                    title="View detailed info"
                    onClick={() => InfoWindow.show(name, metadata)}
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
