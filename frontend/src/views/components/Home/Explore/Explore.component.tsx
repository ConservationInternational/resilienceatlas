import React from 'react';
import { Row } from 'react-foundation';
import Link from 'next/link';

const Explore: React.FC = () => {
  return (
    <div className="m-explore">
      <Row>
        <div className="m-article">
          <h2>EXPLORE THE MAP</h2>
          <p>Evidence-based decision-making to build resilience</p>
          <Link href="/map">
            <a className="btn btn-primary theme-color">Go to the map</a>
          </Link>
        </div>
      </Row>
      <figure />
    </div>
  );
};

export default Explore;
