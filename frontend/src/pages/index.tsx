import MainLayout from 'views/layouts/main';

import Intro from 'views/components/Home/Intro';
import Discover from 'views/components/Home/Discover';
import Section from 'views/components/Home/Section';

import HOME_SECTIONS_DATA from 'data/home-sections';

import type { NextPageWithLayout } from './_app';

const Homepage: NextPageWithLayout = () => {
  const sections = HOME_SECTIONS_DATA.sort((a, b) => a.position - b.position);

  return (
    <>
      <Intro />
      <Discover />
      {sections.map((section) => (
        <Section key={section.id} {...section} />
      ))}
    </>
  );
};

Homepage.Layout = (page) => <MainLayout pageTitle="Welcome">{page}</MainLayout>;

export default Homepage;
