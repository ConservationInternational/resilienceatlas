import MainLayout from 'views/layouts/main';

import Welcome from 'views/components/Home/Welcome';
import Explore from 'views/components/Home/Explore';
import Discover from 'views/components/Home/Discover';
import About from 'views/components/Home/About';

import type { NextPageWithLayout } from './_app';

const Homepage: NextPageWithLayout = () => {
  return (
    <>
      <Welcome />
      <Discover />
      <Explore />
      <About />
    </>
  );
};

Homepage.Layout = (page) => <MainLayout pageTitle="Welcome">{page}</MainLayout>;

export default Homepage;
