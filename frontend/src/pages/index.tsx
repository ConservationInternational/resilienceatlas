import MainLayout from 'views/layouts/main';

import Intro from 'views/components/Home/Intro';
import Journeys from 'views/components/Home/Journeys';
import Section from 'views/components/Home/Section';

import INTRO_DATA from 'data/home-intro';
import JOURNEY_DATA from 'data/home-journey';
import SECTIONS_DATA from 'data/home-sections';

import type { NextPageWithLayout } from './_app';

const Homepage: NextPageWithLayout = () => {
  const intro = INTRO_DATA;
  const journey = JOURNEY_DATA;
  const sections = SECTIONS_DATA.sort((a, b) => a.position - b.position);

  return (
    <>
      <Intro {...intro} />
      <Journeys {...journey} />
      {sections.map((section) => (
        <Section key={section.id} {...section} />
      ))}
    </>
  );
};

Homepage.Layout = (page) => <MainLayout pageTitle="Welcome">{page}</MainLayout>;

export default Homepage;
