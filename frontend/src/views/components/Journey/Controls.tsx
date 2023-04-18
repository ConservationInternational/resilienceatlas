import React from 'react';
import cx from 'classnames';
import Link from 'next/link';
import { withRouter } from 'next/router';
import { T } from '@transifex/react';

import type { WithRouterProps } from 'next/dist/client/with-router';

type ControlsProps = WithRouterProps & {
  slideslength: number;
  journeyIds: number[];
};

const Controls: React.FC<ControlsProps> = ({
  router: {
    query: { id, step },
  },
  slideslength,
  journeyIds,
}) => {
  const isLastJourney = +id === journeyIds[journeyIds.length - 1];
  const journeyIndex = journeyIds.indexOf(+id);
  const isBackHidden = Number(step) < 2;

  return (
    <div
      className={cx('m-controls', {
        'is-first': +step === 1,
        'no-back-button': isBackHidden,
      })}
    >
      <Link href={`/journeys/${id}/step/${Number(step) - 1}`}>
        <a className={cx('btn-prev', { 'is-hidden': isBackHidden })}>
          <T _str="back" />
        </a>
      </Link>

      {+step === slideslength ? (
        <Link href={`/journeys/${isLastJourney ? journeyIds[0] : journeyIds[journeyIndex + 1]}`}>
          <a className="btn-next-journey">
            <T _str="Next journey" />
          </a>
        </Link>
      ) : (
        <Link href={`/journeys/${id}/step/${+step + 1}`}>
          <a className="btn-next">
            <T _str="continue" />
          </a>
        </Link>
      )}
    </div>
  );
};

export default withRouter(Controls);
