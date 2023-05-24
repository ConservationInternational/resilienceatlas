import Datepicker from 'views/shared/datepicker';
import { useCallback } from 'react';
import type { Timeline } from 'types/layer';
import { T } from '@transifex/react';

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
        <label htmlFor="timeline-datepicker" className="timeline-title">
          <T
            _str="Display {layerName} in"
            layerName={layerName}
            _comment="Display {Land use} in {Jan 2020}"
          />
        </label>
        <span className="timeline">
          <Datepicker
            id="timeline-datepicker"
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
