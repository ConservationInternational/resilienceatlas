import React from 'react';

import Link from 'next/link';

const Home: React.FC = () => {
  return (
    <div className="m-home-about">
      <ul>
        <li className="bg-about1">
          <div className="m-article is-center">
            <h2>About RESILIENCE ATLAS</h2>
            <p>Learn more about RESILIENCE ATLAS</p>
            <Link href="/about">
              <a className="btn btn-primary theme-color">Learn more</a>
            </Link>
          </div>
          <p className="credits">
            <a
              target="_blank"
              rel="noopener noreferrer"
              href="https://ci.tandemvault.com/lightboxes/JhUedHo8D?t=o9tS8BbuP#79713241"
            >
              © Mattravel/Alamy Stock Photo
            </a>
          </p>
        </li>
        <li className="bg-about2">
          <div className="m-article is-center">
            <h2>About the data</h2>
            <p>
              RESILIENCE ATLAS visualizes over 60 different datasets - learn more about the data and
              methods behind the site
            </p>
            <Link href="/map">
              <a className="btn btn-primary theme-color">Analysing the data</a>
            </Link>
          </div>
          <p className="credits">
            <a
              target="_blank"
              rel="noopener noreferrer"
              href="https://ci.tandemvault.com/lightboxes/JhUedHo8D?t=o9tS8BbuP#10018225"
            >
              © Design Pics Inc/Alamy Stock Photo
            </a>
          </p>
        </li>
      </ul>
    </div>
  );
};

export default Home;
