import React, { useEffect, useMemo } from 'react';
import Link from 'next/link';
import Slider from 'react-slick';
import { T } from '@transifex/react';

import type { JourneyItem } from 'types/journeys';

type JourneysProps = {
  title: string;
  journeys: JourneyItem[];
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
    <div className="m-home-journeys" data-cy="homepage-section">
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
          {journeys.map((journey) => {
            const { id, background_image, title, subtitle, credits, credits_url } = journey;
            return (
              <li key={id} className="m-slider__item">
                <span
                  className="m-slider__image"
                  style={{
                    ...(background_image && {
                      backgroundImage: `url(${journey.background_image?.original})`,
                    }),
                  }}
                />
                <Link href={`/journeys/${id}`}>
                  <a>
                    <div className="title">
                      {subtitle && <h2>{subtitle}</h2>}
                      <h3>{title}</h3>
                    </div>
                    <span className="journey-link__helper" />
                  </a>
                </Link>
                {credits && credits_url && (
                  <p className="credits">
                    <a href={credits_url} target="_blank" rel="noopener noreferrer">
                      {credits}
                    </a>
                  </p>
                )}
              </li>
            );
          })}
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
