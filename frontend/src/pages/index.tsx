import MainLayout from 'views/layouts/main';

import Intro from 'views/components/Home/Intro';
import Journeys from 'views/components/Home/Journeys';
import Section from 'views/components/Home/Section';

import HOME_SECTIONS_DATA from 'data/home-sections';
import JOURNEY_DATA from 'data/home-journey';

import type { NextPageWithLayout } from './_app';

const Homepage: NextPageWithLayout = () => {
  const sections = HOME_SECTIONS_DATA.sort((a, b) => a.position - b.position);
  const journey = JOURNEY_DATA;

  return (
    <>
      <Intro />
      <Journeys {...journey} />
      {sections.map((section) => (
        <Section key={section.id} {...section} />
      ))}
    </>
  );
};

Homepage.Layout = (page) => <MainLayout pageTitle="Welcome">{page}</MainLayout>;

export default Homepage;
