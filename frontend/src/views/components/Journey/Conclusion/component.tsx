import React, { useState } from 'react';
import DangerousHTML from 'react-dangerous-html';
import cx from 'classnames';

import type { JourneyStep as StaticJourneyStep } from 'types/static-journeys';
import type { JourneyAttributes } from 'types/journeys';

const STATIC_JOURNEYS = process.env.NEXT_PUBLIC_STATIC_JOURNEYS === 'true';

const StaticConclusion: React.FC<StaticJourneyStep> = ({
  background,
  title,
  subtitle,
  content,
  translations,
}) => {
  const [isColapsed, setExpansion] = useState(false);
  return (
    <div className={`m-journey--conclusion ${background}`}>
      <div
        className={cx('content', 'scroll-container', {
          'is-colapsed': isColapsed,
        })}
      >
        <div className="extra-wrapper scroll-wrapper">
          <div className="wrapper scroll-text">
            <h2>{title}</h2>
            <h3>{subtitle}</h3>
            <DangerousHTML html={content} />
          </div>
          <div className="scrolldown-container">
            {/* eslint-disable-next-line  */}
            <a className="scrolldown-link is-jumping" />
          </div>
          <button
            type="button"
            className={cx({
              'btn-colapse': !isColapsed,
              'btn-descolapse': isColapsed,
              'is-colapsed': isColapsed,
            })}
            onClick={() => setExpansion(!isColapsed)}
            aria-label={translations && translations['Colapse/expand overview panel']}
          />
          <div className="shadow" />
        </div>
      </div>
    </div>
  );
};

const Conclusion: React.FC<JourneyAttributes> = ({
  background_color: backgroundColor,
  background_image: backgroundImage,
  title,
  subtitle,
  content,
  translations,
}) => {
  const [isColapsed, setExpansion] = useState(false);
  return (
    <div
      className={`m-journey--conclusion`}
      style={{ backgroundColor, backgroundImage: `url(${backgroundImage?.original})` }}
    >
      <div
        className={cx('content', 'scroll-container', {
          'is-colapsed': isColapsed,
        })}
        style={{ backgroundColor }}
      >
        <div className="extra-wrapper scroll-wrapper">
          <div className="wrapper scroll-text">
            <h2>{title}</h2>
            <h3>{subtitle}</h3>
            <DangerousHTML html={content} />
          </div>
          <div className="scrolldown-container">
            {/* eslint-disable-next-line  */}
            <a className="scrolldown-link is-jumping" />
          </div>
          <button
            type="button"
            className={cx({
              'btn-colapse': !isColapsed,
              'btn-descolapse': isColapsed,
              'is-colapsed': isColapsed,
            })}
            onClick={() => setExpansion(!isColapsed)}
            aria-label={translations && translations['Collapse/expand overview panel']}
          />
          <div
            className="shadow"
            style={{ boxShadow: `inset 0px -50px 26px -14px ${backgroundColor}` }}
          />
        </div>
      </div>
    </div>
  );
};

export default STATIC_JOURNEYS ? StaticConclusion : Conclusion;
