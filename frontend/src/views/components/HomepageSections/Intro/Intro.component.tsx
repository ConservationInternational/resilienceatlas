import React from 'react';

import type { Intro as IntroType } from 'types/homepage';

type IntroProps = IntroType;

const Intro: React.FC<IntroProps> = ({
  title,
  subtitle,
  background_image,
  credits,
  credits_url,
}) => {
  return (
    <div
      className="m-home-intro"
      style={{
        ...(background_image && { backgroundImage: `url(${background_image?.original})` }),
      }}
    >
      <div className="m-home-intro__header">
        {subtitle && <h3>{subtitle}</h3>}
        <h2>{title}</h2>
      </div>
      {background_image && credits && credits_url && (
        <p className="m-home-intro__credits">
          <a target="_blank" rel="noopener noreferrer" href={credits_url}>
            {credits}
          </a>
        </p>
      )}
    </div>
  );
};

export default Intro;
