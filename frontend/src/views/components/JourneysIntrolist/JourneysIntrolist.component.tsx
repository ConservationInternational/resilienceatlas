import React, { useEffect } from 'react';
import Link from 'next/link';
import { T } from '@transifex/react';
import { useRouter } from 'next/router';

import type { JourneyList } from 'types/journeys';

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

export default JourneysIntrolist;
