import { connect } from 'react-redux';
import { setDate } from 'state/modules/layers';
import LegendTimelineComponent from './LegendTimeline.component';
import { timeFormat, timeParse } from 'd3-time-format';
import type { Timeline } from 'types/layer';

const mapDispatchToProps = {
  setDate,
};

interface LegendTimelineContainerProps {
  setDate: (layerId: string, date: Date) => void;
  layerId: string;
  layerName: string;
  selectedDate: string;
  timeline: Timeline;
}

const LegendTimelineContainer = (props: LegendTimelineContainerProps) => {
  const { setDate: setDateAction, layerId, selectedDate, timeline } = props;
  const { format, defaultDate } = timeline;
  const setDate = (date: Date) => setDateAction(layerId, timeFormat(format)(date));
  const parseDate = timeParse(format);
  const selected = selectedDate ? new Date(parseDate(selectedDate)) : defaultDate;

  return <LegendTimelineComponent {...props} setDate={setDate} selected={selected} />;
};

export default connect(null, mapDispatchToProps)(LegendTimelineContainer);
