import React from 'react';
import { WidgetBarChart } from 'views/shared/Widgets/WidgetBarChart';
import { WidgetCategoricalChart } from 'views/shared/Widgets/WidgetCategoricalChart';
import { T } from '@transifex/react';
import TextChart from 'views/shared/Widgets/text-chart/component';

export const LayerAnalysis = ({
  responsiveCharts,
  activeLayers,
  loaded,
  geojson,
  iso,
  countries,
}) => {
  const layers = activeLayers || [];

  if (layers.length && !loaded)
    return (
      <center>
        <T _str="Waiting until layers loaded..." />
      </center>
    );

  const analyzable = layers.filter((l) => l.analysisSuitable);

  if (!layers.length) {
    return (
      <center>
        <T _str="Please toggle some layers on to analyze them." />
      </center>
    );
  }

  if (!analyzable.length) {
    return (
      <center>
        <T _str="None of the active layers can be analyzed." />
      </center>
    );
  }

  const geometry = iso ? JSON.parse(countries[iso].geometry) : geojson;

  return (
    <div className="analysis-content">
      {analyzable.map((l) => {
        switch (l.analysisType) {
          case 'text':
            return (
              <TextChart
                key={l.slug}
                slug={l.slug}
                analysisQuery={l.analysisQuery}
                analysisBody={l.analysisBody}
                analysisTextTemplate={l.analysisTextTemplate}
                name={l.name}
                shortMeta={l.name}
                info={l.info}
                geojson={geometry}
              />
            );
          case 'categorical':
            return (
              <WidgetCategoricalChart
                key={l.slug}
                responsive={responsiveCharts}
                slug={l.slug}
                type={l.type}
                analysisQuery={l.analysisQuery}
                analysisBody={l.analysisBody}
                name={l.name}
                shortMeta={l.name}
                legend={l.legend}
                info={l.info}
                geojson={geometry}
              />
            );
          case 'histogram':
          default:
            return (
              <WidgetBarChart
                key={l.slug}
                responsive={responsiveCharts}
                slug={l.slug}
                type={l.type}
                analysisQuery={l.analysisQuery}
                analysisBody={l.analysisBody}
                name={l.name}
                shortMeta={l.name}
                legend={l.legend}
                info={l.info}
                geojson={geometry}
              />
            );
        }
      })}

      {activeLayers.length !== analyzable.length && (
        <p>
          <T _str="Some active layers can't be analyzed." />
        </p>
      )}
    </div>
  );
};
