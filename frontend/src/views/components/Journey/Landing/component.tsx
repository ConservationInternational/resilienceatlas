import type { JourneyStep as StaticJourneyStep } from 'types/static-journeys';
import type { JourneyAttributes } from 'types/journeys';

const STATIC_JOURNEYS = process.env.NEXT_PUBLIC_STATIC_JOURNEYS === 'true';

const StaticLanding: React.FC<StaticJourneyStep> = ({ title, background, subtitle, theme }) => (
  <div className="l-journey__intro" id="journeyIndexView">
    <div className={`m-journey--landing is-stretch ${background}`}>
      <div className="row">
        <div className="large-12">
          <div className="intro">
            <h1>{title}</h1>
            <h2>{subtitle}</h2>
            <h3>{theme}</h3>
          </div>
        </div>
      </div>
      <div className="logo" />
    </div>
  </div>
);

const Landing: React.FC<JourneyAttributes> = ({
  title,
  background_image: backgroundImage,
  subtitle,
  description,
}) => (
  <div className="l-journey__intro" id="journeyIndexView">
    <div
      className="m-journey--landing is-stretch"
      style={{ backgroundImage: `url(${backgroundImage?.original})` }}
    >
      <div className="row">
        <div className="large-12">
          <div className="intro">
            <h1>{title}</h1>
            <h2>{subtitle}</h2>
            <h3>{description}</h3>
          </div>
        </div>
      </div>
      <div className="logo" />
    </div>
  </div>
);

export default STATIC_JOURNEYS ? StaticLanding : Landing;
