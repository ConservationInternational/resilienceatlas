import type { JourneyStep as StaticJourneyStep } from 'types/static-journeys';
import type { JourneyAttributes } from 'types/journeys';

const STATIC_JOURNEYS = process.env.NEXT_PUBLIC_STATIC_JOURNEYS === 'true';

const StaticChapter: React.FC<StaticJourneyStep> = ({ background, title, content }) => (
  <div className={`m-journey--chapter ${background}`}>
    <div className="chapter-mask--1 is-stretch">
      <div className="wrapper">
        <div className="chapter-intro">
          <h1>{title}</h1>
          <p>{content}</p>
        </div>
      </div>
    </div>
  </div>
);

function hexToRGB(hex: string, alpha: number) {
  if (!hex) return 'rgba(0, 0, 0, 0)';
  const r = parseInt(hex.slice(1, 3), 16),
    g = parseInt(hex.slice(3, 5), 16),
    b = parseInt(hex.slice(5, 7), 16);

  if (alpha) {
    return 'rgba(' + r + ', ' + g + ', ' + b + ', ' + alpha + ')';
  } else {
    return 'rgb(' + r + ', ' + g + ', ' + b + ')';
  }
}

const Chapter: React.FC<JourneyAttributes> = ({
  background_image: backgroundImage,
  title,
  description,
  chapter_number: chapterNumber,
  background_color: backgroundColor,
}) => {
  return (
    <div className="m-journey--chapter">
      <div className="chapter-number-container">
        <div
          className="chapter-number"
          style={{
            background: `
              linear-gradient(0deg, ${hexToRGB(backgroundColor, 0.6)},${hexToRGB(
              backgroundColor,
              0.6,
            )}), linear-gradient(0deg, ${backgroundColor}, ${backgroundColor}), linear-gradient(0deg, #000, #000), url(${
              backgroundImage?.original
            })
            `,
          }}
        >
          {chapterNumber}
        </div>
      </div>
      <div className="wrapper">
        <div className="chapter-intro">
          <h1>{title}</h1>
          <p>{description}</p>
        </div>
      </div>
    </div>
  );
};

export default STATIC_JOURNEYS ? StaticChapter : Chapter;
