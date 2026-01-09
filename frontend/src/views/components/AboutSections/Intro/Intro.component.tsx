import { Row, Column } from 'views/components/Grid';
import type { Image } from 'types/about';

type IntroProps = {
  title: string;
  image: Image;
  image_credits: string;
  image_credits_url: string;
};

const Intro: React.FC<IntroProps> = ({ title, image, image_credits, image_credits_url }) => {
  return (
    <div className="l-hero" style={{ backgroundImage: `url(${image.original})` }}>
      <Row>
        <Column small={12} medium={8}>
          <h1 className="title">{title}</h1>
        </Column>
      </Row>
      <p className="credits">
        <a href={image_credits_url} target="_blank" rel="noopener noreferrer">
          {image_credits}
        </a>
      </p>
    </div>
  );
};

export default Intro;
