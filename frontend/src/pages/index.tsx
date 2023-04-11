import HomepageSections from 'views/components/HomepageSections';

import MainLayout from 'views/layouts/main';

import type { NextPageWithLayout } from './_app';

const Homepage: NextPageWithLayout = () => {
  return <HomepageSections />;
};

Homepage.Layout = (page) => <MainLayout pageTitle="Welcome">{page}</MainLayout>;

export default Homepage;
