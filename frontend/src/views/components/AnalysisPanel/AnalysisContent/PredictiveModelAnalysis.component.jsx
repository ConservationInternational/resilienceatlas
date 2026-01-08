import React, { useMemo } from 'react';
import { WidgetBarChart } from 'views/shared/Widgets/WidgetBarChart';

export const PredictiveModelAnalysis = ({
  responsiveCharts,
  selectedModel,
  model,
  loaded,
  geojson,
}) => {
  const analysisQuery = useMemo(() => {
    if (!model) return null;

    const indicatorsColumn = (model.indicators || [])
      .filter((indicator) => indicator.value !== null && indicator.value !== undefined)
      .map(
        (ind) => `
        {
          "column_name": "${ind.column}",
          "weight": ${ind.value % 1 === 0 ? ind.value : ind.value.toFixed(3)},
          "operation": "${ind.operation || '+'}"
        }`,
      );
    const initialQuery = `select * from getModel(
      '${model.tableName}',
      '[${indicatorsColumn}]')`;

    const query = `with data as (${initialQuery} where
      st_intersects(the_geom, ST_SetSRID (ST_GeomFromGeoJSON('{{geometry}}'),4326))),
      min_max as (select min(value) as min, max(value) as max from data) select width_bucket(value, min, max, 20) as bucket,
      min(value), max(value), count(*) as count from data,
      min_max group by bucket order by bucket`;

    return query;
  }, [model]);

  if (selectedModel && !loaded) return <center>Waiting until layers loaded...</center>;

  if (!selectedModel) {
    return <center>Please toggle some layers on to analyze them.</center>;
  }

  if (!model) {
    return <center>Seems like your model is unavailable or you using wrong atlas.</center>;
  }

  const { description, source } = model;

  return (
    <div className="analysis-content">
      <WidgetBarChart
        key={model.slug}
        responsive={responsiveCharts}
        slug={model.slug}
        type={model.type}
        analysisQuery={analysisQuery}
        analysisBody={model.analysisBody}
        name={model.name}
        shortMeta={model.name}
        metadata={{ description, source }}
        geojson={geojson}
      />
    </div>
  );
};
