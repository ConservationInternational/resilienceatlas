import React, { FC, useEffect } from 'react';
import { RouteComponentProps } from 'react-router-dom';

// Components
import Loader from '@shared/Loader';

import Controls from './Controls';

import Landing from './Landing';
import Conclusion from './Conclusion';
import Embed from './Embed';
import Chapter from './Chapter';

const JOURNEY_TYPES = {
  landing: Landing,
  conclusion: Conclusion,
  embed: Embed,
  chapter: Chapter,
};

// Types
interface P {}

const Journey: FC<P & RouteComponentProps> = ({
  // Actions
  loadJourney,
  // Data
  match: {
    params: { id: currentJourney, step },
  },
  journeysLength,
  journeyLoaded,
  journeyLoading,
  journey: { steps },
}) => {
  useEffect(() => {
    if (!journeyLoaded) loadJourney(currentJourney);
  }, [currentJourney]);

  const stepIndex = step - 1;

  if (!journeyLoaded || !steps[stepIndex]) return null;
  const stepInfo = steps[stepIndex];

  return (
    <div className="l-journey" id="journeyIndexView">
      <Loader loading={journeyLoading} />

      {journeyLoaded &&
        React.createElement(JOURNEY_TYPES[stepInfo.type], { ...stepInfo })}

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
