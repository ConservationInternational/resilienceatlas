import React, { useEffect } from 'react';
import cx from 'classnames';
import Link from 'next/link';

import type { JourneyList } from 'types/journeys';

type JourneysIntrolistProps = {
  journeys: JourneyList;
  journeysLoaded: boolean;
  loadJourneys: () => void;
};

const JourneysIntrolist: React.FC<JourneysIntrolistProps> = ({
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
