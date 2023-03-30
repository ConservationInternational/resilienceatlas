import React from 'react';
import cx from 'classnames';
import Link from 'next/link';
import { withRouter } from 'next/router';

import type { WithRouterProps } from 'next/dist/client/with-router';

type ControlsProps = WithRouterProps & {
  slideslength: number;
  journeysLength: number;
};

const Controls: React.FC<ControlsProps> = ({
  router: {
    query: { id, step },
  },
  slideslength,
  journeysLength,
}) => (
  <div className={cx('m-controls', { 'is-first': +step === 1 })}>
    <Link href={`/journeys/${id}/step/${Number(step) - 1}`}>
      <a className={cx('btn-prev', { 'is-hidden': Number(step) < 2 })}>back</a>
    </Link>

    {+step === slideslength ? (
      <Link href={`/journeys/${+id === journeysLength ? 1 : +id + 1}`}>
        <a className="btn-next-journey">Next journey</a>
      </Link>
    ) : (
      <Link href={`/journeys/${id}/step/${+step + 1}`}>
        <a className="btn-next">continue</a>
      </Link>
    )}
  </div>
);

export default withRouter(Controls);
