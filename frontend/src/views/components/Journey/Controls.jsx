import React from 'react';
import cx from 'classnames';
import { withRouter, NavLink } from 'react-router-dom';

const Controls = ({
  match: {
    params: { id, step },
  },
  slideslength,
  journeysLength,
}) => (
  <div className={cx('m-controls', { 'is-first': +step === 1 })}>
    <NavLink
      to={`/journeys/${id}/step/${step - 1}`}
      className={cx('btn-prev', { 'is-hidden': step < 2 })}
    >
      back
    </NavLink>

    {+step === slideslength ? (
      <NavLink
        to={`/journeys/${+id === journeysLength ? 1 : +id + 1}`}
        className="btn-next-journey"
      >
        Next journey
      </NavLink>
    ) : (
      <NavLink to={`/journeys/${id}/step/${+step + 1}`} className="btn-next">
        continue
      </NavLink>
    )}
  </div>
);

export default withRouter(Controls);
