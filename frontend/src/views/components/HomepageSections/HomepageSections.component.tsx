import React, { useEffect, useMemo } from 'react';

import Intro from './Intro';
import Journeys from './Journeys';
import Section from './Section';

import type { Intro as IntroType, JourneyItem, SectionItem } from 'types/homepage';

const HOMEPAGE_COMPONENTS = {
  journeys: Journeys,
  section: Section,
};

type HomepageSectionsProps = {
  homepage: {
    intro: IntroType;
    journeys: JourneyItem[];
    sections: SectionItem[];
  };
  homepageLoaded: boolean;
  loadHomepage: () => void;
};

const HomepageSections: React.FC<HomepageSectionsProps> = ({
  homepage,
  homepageLoaded,
  loadHomepage,
}) => {
  const { intro, journeys = [], sections = [] } = homepage;

  useEffect(() => {
    if (!homepageLoaded) loadHomepage();
  }, [homepageLoaded, loadHomepage]);

  const homepageSections = useMemo(
    () =>
      [
        ...journeys.map((journey) => ({
          type: 'journeys',
          section: journey,
        })),
        ...sections.map((section) => ({
          type: 'section',
          section: section,
        })),
      ].sort((a, b) => a.section.position - b.section.position),
    [journeys, sections],
  );

  if (!homepageLoaded) return null;

  return (
    <>
      <Intro {...intro} />
      {homepageSections.map(({ type, section }, idx) => {
        const Component = HOMEPAGE_COMPONENTS[type];
        if (!Component) return null;
        return <Component key={idx} {...section} />;
      })}
    </>
  );
};

export default HomepageSections;
