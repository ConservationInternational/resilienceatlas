import React, { useEffect } from 'react';
import { useRouter } from 'next/router';
import Loader from 'views/shared/Loader';
import Landing from './Landing';
import Controls from './Controls';
import Conclusion from './Conclusion';
import Embed from './Embed';
import Chapter from './Chapter';

import type { FC } from 'react';
import type { WithRouterProps } from 'next/dist/client/with-router';
import type { JourneyItem } from 'types/journeys';
import type { Translations } from 'types/transifex';

type JourneyProps = WithRouterProps & {
  // Actions
  loadJourney: (id: string, locale: string) => void;
  loadJourneys: (locale: string) => void;
  // Data
  query: {
    id: string;
    step: string;
  };
  journeysLength: number;
  journeyLoaded: boolean;
  journeyLoading: boolean;
  journeysLoadedLocale: string;
  journey: JourneyItem;
  journeysLoaded: boolean;
  journeysById: JourneyItem[];
  translations: Translations;
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
  loadJourneys,
  // Data
  query: { id: currentJourney, step },
  journeyLoaded,
  journeyLoading,
  journey,
  journeysLoaded,
  journeysLoadedLocale,
  journeysById,
  translations,
}) => {
  const { locale } = useRouter();
  useEffect(() => {
    if (currentJourney && (!journeyLoaded || journeysLoadedLocale !== locale)) {
      loadJourney(currentJourney, locale);
    }
  }, [currentJourney, journeyLoaded, loadJourney, locale, journeysLoadedLocale]);

  useEffect(() => {
    if (!journeysLoaded || journeysLoadedLocale !== locale) loadJourneys(locale);
  }, [journeysLoaded, loadJourneys, locale, journeysLoadedLocale]);

  const journeyIds = journeysById && Object.keys(journeysById).map((id) => +id);
  const stepIndex = Number(step) - 1;
  const { steps } = journey || {};

  // Defensive checks for journey and step data
  if (!journeyLoaded || !journey || !steps || !Array.isArray(steps)) return null;

  // Check if step index is valid
  if (stepIndex < 0 || stepIndex >= steps.length) return null;

  const stepInfo = steps[stepIndex];
  if (!stepInfo) return null;

  const { attributes } = stepInfo;
  const { step_type: stepType } = attributes;
  return (
    <div className="l-journey" id="journeyIndexView">
      <Loader loading={journeyLoading} />

      {journeyLoaded &&
        React.createElement(JOURNEY_TYPES[stepType], {
          ...attributes,
          translations,
          isLastStep: stepIndex === steps.length - 1,
        })}

      <Controls journeyIds={journeyIds} slideslength={steps.length} />

      {!journeyLoading && stepType !== 'embed' && (
        <p className={`credits ${stepType}`}>
          <a target="_blank" rel="noopener noreferrer" href={attributes.credits_url}>
            {attributes.credits}
          </a>
        </p>
      )}
    </div>
  );
};

export default Journey;
