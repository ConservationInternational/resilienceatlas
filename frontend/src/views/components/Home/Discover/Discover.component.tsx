import React from 'react';
import Link from 'next/link';
import cx from 'classnames';
import Slider from 'react-slick';

import { JOURNEY_SLIDES } from 'views/utils';

const Discover: React.FC = () => {
  return (
    <div className="m-discover">
      <div className="m-discover__title">
        <h2>Discover Journeys</h2>
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
          {JOURNEY_SLIDES.map((j, i) => (
            <li key={`slide_${i + 1}`} className={cx('m-slider__item', `journey${i + 1}bg0`)}>
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

      <div className="m-discover__bottom">
        <Link href="/journeys">
          <a className="btn btn-primary">More journeys</a>
        </Link>
      </div>
    </div>
  );
};

export default Discover;
