import type { JourneyAttributes } from 'types/journeys';
import { hexToRGB } from 'utilities/helpers';

const Chapter: React.FC<JourneyAttributes> = ({
  background_image: backgroundImage,
  title,
  description,
  chapter_number: chapterNumber,
  background_color: backgroundColor,
}) => (
  <div
    className="m-journey--chapter"
    // Fallback for old journeys with number masked directly on the image
    {...(backgroundColor && backgroundColor !== '#000000'
      ? {}
      : { style: { backgroundImage: `url(${backgroundImage?.original})` } })}
  >
    <div className="chapter-number-container">
      <div
        className="chapter-number"
        style={{
          background:
            !backgroundImage?.original &&
            `linear-gradient(0deg, ${hexToRGB(backgroundColor, 0.6)},${hexToRGB(backgroundColor, 0.6)}), linear-gradient(0deg, ${backgroundColor}, ${backgroundColor}), linear-gradient(0deg, #000, #000), url(${backgroundImage?.original})`,
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

export default Chapter;
