import React from 'react';
import Link from 'next/link';
import { T } from '@transifex/react';

import JourneySlider from 'views/components/JourneySlider';

type JourneysProps = {
  title: string;
};

const Journeys: React.FC<JourneysProps> = ({ title }) => {
  return (
    <div className="m-home-journeys" data-cy="homepage-section">
      <div className="m-home-journeys__title">
        <h2>{title}</h2>
      </div>
      <JourneySlider />

      <div className="m-home-journeys__bottom">
        <Link href="/journeys" className="btn btn-primary">
          <T _str="More journeys" />
        </Link>
      </div>
    </div>
  );
};

export default Journeys;
