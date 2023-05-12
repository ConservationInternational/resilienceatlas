import type { FC } from 'react';
import { useMemo } from 'react';
import { T } from '@transifex/react';
import { t } from '@transifex/native';

import InfoWindow from 'views/components/InfoWindow';
import { useWidget } from 'utilities';
import type { TextChartProps } from './types';
import DownloadCsv from '../DownloadCsv';

export const TextChart: FC<TextChartProps> = ({
  slug,
  name,
  analysisQuery,
  analysisBody,
  analysisTextTemplate,
  shortMeta,
  info,
  geojson,
}: TextChartProps) => {
  const { rootWidgetProps, loaded, data, noData } = useWidget(
    { slug, geojson },
    { analysisQuery, analysisBody },
  );

  const sentence = useMemo(() => {
    if (!data?.rows?.[0]) {
      return null;
    }

    return Object.keys(data.rows[0]).reduce((res, key) => {
      let value: string | number = data.rows[0][key];
      if (typeof value === 'number') {
        value = value.toFixed(2);
      }

      return res.replace(`{{${key}}}`, `<strong>${value}</strong>`);
    }, analysisTextTemplate);
  }, [data, analysisTextTemplate]);

  return (
    <div {...rootWidgetProps()}>
      <div className="name">{name}</div>
      {loaded && (
        <>
          {noData && (
            <div className="widget-no-data">
              <h3>
                <T _str="NO DATA AVAILABLE" />
              </h3>
            </div>
          )}
          {!noData && (
            <>
              <div className="widget-text-chart" dangerouslySetInnerHTML={{ __html: sentence }} />
              {shortMeta && (
                <div className="meta-short">
                  {shortMeta}

                  {!noData && <DownloadCsv data={data} name={slug} />}

                  {info && (
                    <button
                      type="button"
                      className="btn-analysis btn-analysis__info"
                      data-info={info}
                      data-name={name}
                      title={t('View detailed info')}
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
          )}
        </>
      )}
    </div>
  );
};

export default TextChart;
