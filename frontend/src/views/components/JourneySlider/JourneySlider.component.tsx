import React, { useEffect } from 'react';
import cx from 'classnames';
import Link from 'next/link';
import Slider from 'react-slick';

import type { JourneyItem } from 'types/journeys';
import { JOURNEY_SLIDES as STATIC_JOURNEY_SLIDES } from 'views/utils';
const STATIC_JOURNEYS = process.env.NEXT_PUBLIC_STATIC_JOURNEYS === 'true';

type JourneySliderProps = {
  journeys: JourneyItem[];
  journeysLoaded: boolean;
  loadJourneys: () => void;
};

const StaticJourneySlider: React.FC = () => {
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
      >
        {STATIC_JOURNEY_SLIDES.map((j, i) => (
          <li key={`slide_${i + 1}`} className={cx('m-slider__item static', `journey${i + 1}bg0`)}>
            <Link href={`/journeys/${i + 1}`}>
              <a className={j.linkClassName}>
                <div className="title">
                  <h3>{j.title}</h3>
                  <h2>{j.subtitle}</h2>
                </div>
                <span className="journey-link__helper" />
              </a>
            </Link>
            <p className="credits">
              <a href={j.credits.link} target="_blank" rel="noopener noreferrer">
                {j.credits.title}
              </a>
            </p>
          </li>
        ))}
      </Slider>
    </div>
  );
};

const JourneySlider: React.FC<JourneySliderProps> = ({
  journeys,
  journeysLoaded,
  loadJourneys,
}) => {
  useEffect(() => {
    if (!journeysLoaded) loadJourneys();
  }, [journeysLoaded, loadJourneys]);
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

export default STATIC_JOURNEYS ? StaticJourneySlider : JourneySlider;
