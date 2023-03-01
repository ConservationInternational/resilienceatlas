import round from './Legend_round';
import custom from './Legend_custom';
import border from './Legend_border';
import choropleth from './Legend_choropleth';
import chart from './Legend_chart';
import legendimage from './Legend_image';

export default {
  custom,
  border,
  choropleth,
  legendimage,
  // need to export an object because of dash
  'legend-round': round,
  chart,
};
