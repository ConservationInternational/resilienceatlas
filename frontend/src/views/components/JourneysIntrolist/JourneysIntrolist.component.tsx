import React, { useEffect } from 'react';
import cx from 'classnames';
import Link from 'next/link';
import { T } from '@transifex/react';
import { useRouter } from 'next/router';

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
  loadJourneys: (locale: string) => void;
  journeysLoadedLocale: string;
};

const JourneysIntrolist: React.FC<JourneysIntrolistProps> = ({
  journeys,
  journeysLoaded,
  loadJourneys,
  journeysLoadedLocale,
}) => {
  const { locale } = useRouter();
  useEffect(() => {
    if (!journeysLoaded || journeysLoadedLocale !== locale) loadJourneys(locale);
  }, [journeysLoaded, loadJourneys, locale, journeysLoadedLocale]);

  return (
    <ul className="m-journey__grid">
      {journeys
        .filter((journey) => journey.attributes.published)
        .map((journey, i: number) => {
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
                  <a className="btn btn-secondary theme-bg-color">
                    <T _str="Learn more" />
                  </a>
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
};

const StaticJourneysIntrolist: React.FC<StaticJourneysIntrolistProps> = ({
  journeys,
  journeysLoaded,
  loadJourneys,
}) => {
  useEffect(() => {
    if (!journeysLoaded) loadJourneys();
  }, [journeysLoaded, loadJourneys]);

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
              <a className="btn btn-secondary theme-bg-color">
                <T _str="Learn more" />
              </a>
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

export default STATIC_JOURNEYS ? StaticJourneysIntrolist : JourneysIntrolist;
