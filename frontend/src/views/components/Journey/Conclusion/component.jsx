import React, { useState } from 'react';
import DangerousHTML from 'react-dangerous-html';
import cx from 'classnames';

const Conclusion = ({ background, title, subtitle, content }) => {
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
            aria-label="Colapse/expand overview panel"
          />
          <div className="shadow" />
        </div>
      </div>
    </div>
  );
};

export default Conclusion;
