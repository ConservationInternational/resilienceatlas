import { useMemo } from 'react';

import MainLayout from 'views/layouts/main';

import Intro from 'views/components/Home/Intro';
import Journeys from 'views/components/Home/Journeys';
import Section from 'views/components/Home/Section';

import INTRO_DATA from 'data/home-intro';
import JOURNEY_DATA from 'data/home-journey';
import SECTIONS_DATA from 'data/home-sections';

import type { NextPageWithLayout } from './_app';

const HOMEPAGE_COMPONENTS = {
  journeys: Journeys,
  section: Section,
};

const Homepage: NextPageWithLayout = () => {
  const intro = INTRO_DATA;
  const journey = JOURNEY_DATA;
  const sections = SECTIONS_DATA;

  const homepageItems = useMemo(
    () =>
      [
        {
          type: 'journeys',
          item: journey,
        },
        ...sections.map((section) => ({
          type: 'section',
          item: section,
        })),
      ].sort((a, b) => a.item.position - b.item.position),
    [journey, sections],
  );

  return (
    <>
      <Intro {...intro} />
      {homepageItems.map(({ type, item: itemProps }) => {
        const Component = HOMEPAGE_COMPONENTS[type];
        if (!Component) return null;
        return <Component key={`${itemProps.position}-${itemProps.id}`} {...itemProps} />;
      })}
    </>
  );
};

Homepage.Layout = (page) => <MainLayout pageTitle="Welcome">{page}</MainLayout>;

export default Homepage;
