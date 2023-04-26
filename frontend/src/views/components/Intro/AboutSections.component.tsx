import React, { useEffect } from 'react';
import type { About } from 'types/about';
import { useRouter } from 'next/router';
import { Row, Column } from 'react-foundation';

type AboutSectionsProps = {
  about: About;
  aboutLoaded: boolean;
  aboutLoadedLocale: string;
  loadAbout: (locale: string) => void;
};

const AboutSections: React.FC<AboutSectionsProps> = ({
  about,
  aboutLoaded,
  aboutLoadedLocale,
  loadAbout,
}) => {
  const { locale } = useRouter();
  useEffect(() => {
    if (!aboutLoaded || aboutLoadedLocale !== locale) {
      loadAbout(locale);
    }
  }, [loadAbout, locale, aboutLoadedLocale, aboutLoaded]);

  if (!aboutLoaded || !about) return null;
  const { intro } = about;
  const { title, image, image_credits, image_credits_url } = intro;
  return (
    <div className="l-content">
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
    </div>
  );
};

export default AboutSections;
