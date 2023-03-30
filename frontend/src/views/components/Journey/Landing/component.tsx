import type { JourneyStep } from 'types/journeys';

const Landing: React.FC<JourneyStep> = ({ title, background, subtitle, theme }) => (
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

export default Landing;
