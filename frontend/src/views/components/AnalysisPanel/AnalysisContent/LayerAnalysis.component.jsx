import React from 'react';
import { WidgetBarChart } from 'views/shared/Widgets/WidgetBarChart';
import { T } from '@transifex/react';

export const LayerAnalysis = ({
  responsiveCharts,
  activeLayers,
  loaded,
  geojson,
  iso,
  countries,
}) => {
  if (activeLayers.length && !loaded)
    return (
      <center>
        <T _str="Waiting until layers loaded..." />
      </center>
    );

  const analyzable = activeLayers.filter((l) => l.analysisSuitable);

  if (!activeLayers.length) {
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
      {analyzable.map((l) => (
        <WidgetBarChart
          key={l.slug}
          responsive={responsiveCharts}
          slug={l.slug}
          type={l.type}
          analysisQuery={l.analysisQuery}
          analysisBody={l.analysisBody}
          name={l.name}
          meta_short={l.name}
          legend={l.legend}
          metadata={JSON.parse(l.info || 'null')}
          geojson={geometry}
        />
      ))}

      {activeLayers.length !== analyzable.length && (
        <p>
          <T _str="Some active layers can't be analyzed." />
        </p>
      )}
    </div>
  );
};
