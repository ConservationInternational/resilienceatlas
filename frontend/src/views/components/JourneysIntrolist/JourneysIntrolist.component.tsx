import React, { useEffect } from 'react';
import cx from 'classnames';
import Link from 'next/link';

import type { JourneyList } from 'types/journeys';
import type { JourneyList as StaticJourneyList } from 'types/static-journeys';

const STATIC_JOURNEYS = process.env.NEXT_PUBLIC_STATIC_JOURNEYS === 'true';

type StaticJourneysIntrolistProps = {
  journeys: StaticJourneyList;
  journeysLoaded: boolean;
  loadJourneys: () => void;
};

type JourneysIntrolistProps = {
  journeys: JourneyList;
  journeysLoaded: boolean;
  loadJourneys: () => void;
};

const JourneysIntrolist: React.FC<StaticJourneysIntrolistProps | JourneysIntrolistProps> = ({
  journeys,
  journeysLoaded,
  loadJourneys,
}) => {
  useEffect(() => {
    if (!journeysLoaded) loadJourneys();
  }, [journeysLoaded, loadJourneys]);
  if (!STATIC_JOURNEYS) {
    return (
      <ul className="m-journey__grid">
        {journeys.map((journey, i: number) => {
          const {
            attributes: {
              title,
              theme,
              background_image: { original: image },
            },
            id,
          } = journey;
          return (
            <li className="m-journey__gridelement" data-index={i} key={id}>
              <div className="text">
                <span className="title">
                  <h2>
                    <Link href={`/journeys/${id}`}>
                      <a>{title}</a>
                    </Link>
                  </h2>
                </span>
                <span className="description">
                  <p>{theme}</p>
                </span>
                <Link href={`/journeys/${id}`}>
                  <a className="btn btn-secondary theme-bg-color">Learn more</a>
                </Link>
              </div>
              <Link href={`/journeys/${id}`}>
                <a
                  className="pic"
                  style={{
                    backgroundImage: `url(${image})`,
                  }}
                >
                  <span className="background" />
                </a>
              </Link>
            </li>
          );
        })}
      </ul>
    );
  }
  return (
    <ul className="m-journey__grid">
      {journeys.map((j, i) => (
        <li className={cx('m-journey__gridelement', j['bg-big'])} data-index={i} key={j.id}>
          <div className="text">
            <span className="title">
              <h2>
                <Link href={`/journeys/${j.id}`}>
                  <a>{j.title}</a>
                </Link>
              </h2>
            </span>
            <span className="description">
              <p>{j.theme}</p>
            </span>
            <Link href={`/journeys/${j.id}`}>
              <a className="btn btn-secondary theme-bg-color">Learn more</a>
            </Link>
          </div>
          <Link href={`/journeys/${j.id}`}>
            <a className="pic">
              <span className="background" />
            </a>
          </Link>
        </li>
      ))}
    </ul>
  );
};

export default JourneysIntrolist;
