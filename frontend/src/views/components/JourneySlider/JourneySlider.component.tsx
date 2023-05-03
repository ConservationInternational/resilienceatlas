import React, { useEffect } from 'react';
import Link from 'next/link';
import Slider from 'react-slick';
import { useRouter } from 'next/router';

import type { JourneyItem } from 'types/journeys';

type JourneySliderProps = {
  journeys: JourneyItem[];
  journeysLoaded: boolean;
  loadJourneys: (locale: string) => void;
  journeysLoadedLocale: string;
};

const JourneySlider: React.FC<JourneySliderProps> = ({
  journeys,
  journeysLoaded,
  loadJourneys,
  journeysLoadedLocale,
}) => {
  const { locale } = useRouter();
  useEffect(() => {
    if (!journeysLoaded || journeysLoadedLocale !== locale) {
      loadJourneys(locale);
    }
  }, [journeysLoaded, loadJourneys, locale, journeysLoadedLocale]);
  if (!journeys) return null;
  return (
    <div className="m-slider" id="sliderView">
      <Slider
        className="m-slider__itemlist"
        slidesToShow={1}
        centerMode
        centerPadding="120px"
        draggable
        infinite
        arrows
        responsive={[
          {
            breakpoint: 800,
            settings: {
              centerMode: false,
            },
          },
        ]}
      >
        {journeys.map((journey) => {
          const { attributes, id } = journey || {};
          if (!attributes) return null;
          const {
            title,
            subtitle,
            credits_url: creditsLink,
            credits,
            background_image: { original },
          } = attributes;
          return (
            <li key={`slide_${id}`} className="m-slider__item">
              <Link href={`/journeys/${id}`}>
                <a
                  className="journey-link-container"
                  style={{ backgroundImage: `url(${original})` }}
                >
                  <div className="title">
                    <h3>{title}</h3>
                    <h2>{subtitle}</h2>
                  </div>
                </a>
              </Link>
              <p className="credits">
                <a href={creditsLink} target="_blank" rel="noopener noreferrer">
                  {credits}
                </a>
              </p>
            </li>
          );
        })}
      </Slider>
    </div>
  );
};

export default JourneySlider;
