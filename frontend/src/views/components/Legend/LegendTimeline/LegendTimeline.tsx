import { connect } from 'react-redux';
import { setDate } from 'state/modules/layers';
import LegendTimelineComponent from './LegendTimeline.component';
import type { Timeline } from 'types/layer';
import format from 'date-fns/format';

const mapDispatchToProps = {
  setDate,
};

interface LegendTimelineContainerProps {
  setDate: (layerId: string, date: string) => void;
  layerId: string;
  layerName: string;
  selectedDate: string;
  timeline: Timeline;
}

const LegendTimelineContainer = (props: LegendTimelineContainerProps) => {
  const { setDate: setDateAction, layerId, selectedDate, timeline } = props;
  const { defaultDate } = timeline;
  // We are storing the date as a string in the state with this default format not related to the
  // format to display it on the datepicker
  const setDate = (date: Date) => setDateAction(layerId, format(date, 'yyyy-MM-dd'));
  const selected = selectedDate ? new Date(selectedDate) : defaultDate;

  return <LegendTimelineComponent {...props} setDate={setDate} selected={selected} />;
};

export default connect(null, mapDispatchToProps)(LegendTimelineContainer);
