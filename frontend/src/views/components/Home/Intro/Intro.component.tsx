import React from 'react';

type IntroProps = {
  title: string;
  subtitle?: string;
  background_image: string;
  credits?: string;
  credits_url?: string;
};

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
        backgroundImage: `url(${background_image})`,
      }}
    >
      <div className="m-home-intro__header">
        <h3>{subtitle}</h3>
        <h2>{title}</h2>
      </div>
      {background_image && credits && (
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
