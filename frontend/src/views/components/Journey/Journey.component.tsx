import React, { useEffect } from 'react';

// Components
import Loader from 'views/shared/Loader';

import Controls from './Controls';
import Landing from './Landing';
import Conclusion from './Conclusion';
import Embed from './Embed';
import Chapter from './Chapter';

import type { FC } from 'react';
import type { WithRouterProps } from 'next/dist/client/with-router';
import type { JourneyDetail } from 'types/journeys';

type JourneyProps = WithRouterProps & {
  // Actions
  loadJourney: (id: string) => void;
  // Data
  query: {
    id: string;
    step: string;
  };
  journeysLength: number;
  journeyLoaded: boolean;
  journeyLoading: boolean;
  journey: JourneyDetail;
};

const JOURNEY_TYPES = {
  landing: Landing,
  conclusion: Conclusion,
  embed: Embed,
  chapter: Chapter,
};

const Journey: FC<JourneyProps> = ({
  // Actions
  loadJourney,
  // Data
  query: { id: currentJourney, step },
  journeysLength,
  journeyLoaded,
  journeyLoading,
  journey: { steps },
}) => {
  useEffect(() => {
    if (!journeyLoaded && currentJourney) loadJourney(currentJourney);
  }, [currentJourney, journeyLoaded, loadJourney]);

  const stepIndex = Number(step) - 1;

  if (!journeyLoaded || !steps[stepIndex]) return null;
  const stepInfo = steps[stepIndex];

  return (
    <div className="l-journey" id="journeyIndexView">
      <Loader loading={journeyLoading} />

      {journeyLoaded && React.createElement(JOURNEY_TYPES[stepInfo.type], { ...stepInfo })}

      <Controls journeysLength={journeysLength} slideslength={steps.length} />

      {!journeyLoading && stepInfo.type !== 'embed'}
      <p className={`credits ${stepInfo.type}`}>
        <a target="_blank" rel="noopener noreferrer" href={stepInfo.creditsUrl}>
          {stepInfo.credits}
        </a>
      </p>
    </div>
  );
};

export default Journey;
