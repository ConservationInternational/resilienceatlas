import React, { useEffect } from 'react';
import cx from 'classnames';
import { NavLink } from 'react-router-dom';

const JourneysIntrolist = ({ journeys, journeysLoaded, loadJourneys }) => {
  useEffect(() => {
    if (!journeysLoaded) loadJourneys();
  }, []);

  return (
    <ul className="m-journey__grid">
      {journeys.map((j, i) => (
        <li
          className={cx('m-journey__gridelement', j['bg-big'])}
          data-index={i}
          key={j.id}
        >
          <div className="text">
            <span className="title">
              <h2>
                <NavLink to={`/journeys/${j.id}`}>{j.title}</NavLink>
              </h2>
            </span>
            <span className="description">
              <p>{j.theme}</p>
            </span>
            <NavLink
              to={`/journeys/${j.id}`}
              className="btn btn-secondary theme-bg-color"
            >
              Learn more
            </NavLink>
          </div>
          <NavLink to={`/journeys/${j.id}`} className="pic">
            <span className="background" />
          </NavLink>
        </li>
      ))}
    </ul>
  );
};

export default JourneysIntrolist;
