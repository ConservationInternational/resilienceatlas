import type { GeoJSON } from 'geojson';

export interface TextChartProps {
  /** Slug of the layer */
  slug: string;
  /** Name of the layer */
  name: string;
  /** Query that performs the analysis */
  analysisQuery: string;
  /** Body of the analysis */
  analysisBody: string;
  /** Sentence template of the analysis */
  analysisTextTemplate: string;
  /** Short metadata description of the chart */
  shortMeta?: string;
  /** Long description of the chart/analysis */
  info?: string;
  /** Geometry being analyzed */
  geojson: GeoJSON;
}
