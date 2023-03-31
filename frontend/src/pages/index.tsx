import cx from 'classnames';
import Link from 'next/link';
import Slider from 'react-slick';
import { Row } from 'react-foundation';

import MainLayout from 'views/layouts/main';
import { JOURNEY_SLIDES } from 'views/utils';

import type { NextPageWithLayout } from './_app';

const Homepage: NextPageWithLayout = () => {
  return (
    <>
      <div className="m-welcome">
        <header>
          <h3>Welcome to</h3>
          <h2>RESILIENCE ATLAS</h2>
        </header>
      </div>

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

      <div className="m-explore">
        <Row>
          <div className="m-article">
            <h2>EXPLORE THE MAP</h2>
            <p>Evidence-based decision-making to build resilience</p>
            <Link href="/map">
              <a className="btn btn-primary theme-color">Go to the map</a>
            </Link>
          </div>
        </Row>
        <figure />
      </div>

      <div className="m-home-about">
        <ul>
          <li className="bg-about1">
            <div className="m-article is-center">
              <h2>About RESILIENCE ATLAS</h2>
              <p>Learn more about RESILIENCE ATLAS</p>
              <Link href="/about">
                <a className="btn btn-primary theme-color">Learn more</a>
              </Link>
            </div>
            <p className="credits">
              <a
                target="_blank"
                rel="noopener noreferrer"
                href="https://ci.tandemvault.com/lightboxes/JhUedHo8D?t=o9tS8BbuP#79713241"
              >
                © Mattravel/Alamy Stock Photo
              </a>
            </p>
          </li>
          <li className="bg-about2">
            <div className="m-article is-center">
              <h2>About the data</h2>
              <p>
                RESILIENCE ATLAS visualizes over 60 different datasets - learn more about the data
                and methods behind the site
              </p>
              <Link href="/map">
                <a className="btn btn-primary theme-color">Analysing the data</a>
              </Link>
            </div>
            <p className="credits">
              <a
                target="_blank"
                rel="noopener noreferrer"
                href="https://ci.tandemvault.com/lightboxes/JhUedHo8D?t=o9tS8BbuP#10018225"
              >
                © Design Pics Inc/Alamy Stock Photo
              </a>
            </p>
          </li>
        </ul>
      </div>
    </>
  );
};

Homepage.Layout = (page) => <MainLayout pageTitle="Welcome">{page}</MainLayout>;

export default Homepage;
