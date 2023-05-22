import Datepicker from 'views/shared/datepicker/component';
import { useCallback } from 'react';
import type { Timeline } from 'types/layer';

interface LegendTimelineProps {
  timeline: Timeline;
  layerName: string;
  setDate: (date: Date) => void;
  selected: Date;
}

const LegendTimeline = ({ timeline, layerName, setDate, selected }: LegendTimelineProps) => {
  const { startDate, endDate, period, steps } = timeline;

  const getResolution = useCallback(() => {
    const resolutionPeriods = {
      yearly: 'year',
      monthly: 'month',
      daily: 'day',
    };
    return resolutionPeriods[period];
  }, [period]);

  return (
    <>
      <div className="m-legend-timeline">
        <span className="timeline-title">Display {layerName} in</span>
        <span className="timeline">
          <Datepicker
            startDate={startDate}
            endDate={endDate}
            selected={selected}
            onSelect={setDate}
            resolution={getResolution()}
            includeDates={steps.length && steps.map((step) => new Date(step))}
          />
        </span>
      </div>
    </>
  );
};

export default LegendTimeline;
