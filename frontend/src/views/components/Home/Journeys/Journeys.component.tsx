import React, { useEffect, useMemo } from 'react';
import Link from 'next/link';
import Slider from 'react-slick';
import { T } from '@transifex/react';

import type { JourneyList } from 'types/journeys';

type JourneysProps = {
  title: string;
  journeys: JourneyList;
  journeysLoaded: boolean;
  loadJourneys: () => void;
};

const Journeys: React.FC<JourneysProps> = ({
  title,
  journeys: journeysData,
  journeysLoaded,
  loadJourneys,
}) => {
  useEffect(() => {
    if (!journeysLoaded) loadJourneys();
  }, [journeysLoaded, loadJourneys]);

  const journeys = useMemo(
    () => journeysData.map(({ id, attributes }) => ({ id, ...attributes })),
    [journeysData],
  );

  if (!journeysLoaded) return null;

  return (
    <div className="m-home-journeys">
      <div className="m-home-journeys__title">
        <h2>{title}</h2>
      </div>
      <div className="m-slider" id="sliderView">
        <Slider
          className="m-slider__itemlist"
          slidesToShow={1}
          centerMode
          centerPadding="120px"
          draggable
          infinite
          arrows
        >
          {journeys.map((journey) => (
            <li key={journey.id} className="m-slider__item">
              <span
                className="m-slider__image"
                style={{
                  backgroundImage: `url(${journey.background_image?.original})`,
                }}
              />
              <Link href={`/journeys/${journey.id}`}>
                <a>
                  <div className="title">
                    <h3>{journey.title}</h3>
                    <h2>{journey.subtitle}</h2>
                  </div>
                  <span className="journey-link__helper" />
                </a>
              </Link>
              <p className="credits">
                <a href={journey.credits_url} target="_blank" rel="noopener noreferrer">
                  {journey.credits}
                </a>
              </p>
            </li>
          ))}
        </Slider>
      </div>

      <div className="m-home-journeys__bottom">
        <Link href="/journeys">
          <a className="btn btn-primary">
            <T _str="More journeys" />
          </a>
        </Link>
      </div>
    </div>
  );
};

export default Journeys;
