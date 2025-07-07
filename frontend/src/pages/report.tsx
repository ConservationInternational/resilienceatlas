import { Row, Column } from 'react-foundation';

import ReportLayout from 'views/layouts/report';
import MapView from 'views/components/Map';
import Legend from 'views/components/Legend';
import { LayerAnalysis } from 'views/components/AnalysisPanel/AnalysisContent';
import Loader from 'views/shared/Loader';
import { T } from '@transifex/react';
import type { NextPageWithLayout } from './_app';
import { getServerSideTranslations } from 'i18n';

import type { GetServerSidePropsContext } from 'next';
import { useSetServerSideTranslations, withTranslations } from 'utilities/hooks/transifex';

const ReportPage: NextPageWithLayout = ({ translations, setTranslations }) => {
  useSetServerSideTranslations({ setTranslations, translations });
  return (
    <div className="l-content">
      <div className="l-content m-report-page">
        <Row>
          <Column small={12}>
            <h2>
              <T _str="Analysis report" />
            </h2>
            <MapView />
            <Loader />

            <Legend />

            <LayerAnalysis responsiveCharts />

            <a href="http://resilienceatlas.org/" className="logo">
              <span />
            </a>
          </Column>
        </Row>
      </div>
    </div>
  );
};

ReportPage.Layout = (page, translations) => (
  <ReportLayout pageTitle={translations['Report']}>{page}</ReportLayout>
);

export default withTranslations(ReportPage);

export async function getServerSideProps(context: GetServerSidePropsContext) {
  const { translations } = await getServerSideTranslations(context);
  return {
    props: {
      translations,
    },
  };
}
