import { Row, Column } from 'react-foundation';

import ReportLayout from 'views/layouts/report';
import MapView from 'views/components/Map';
import Legend from 'views/components/Legend';
import { LayerAnalysis } from 'views/components/AnalysisPanel/AnalysisContent';
import Loader from 'views/shared/Loader';
import { T } from '@transifex/react';
import type { NextPageWithLayout } from './_app';

const ReportPage: NextPageWithLayout = () => (
  <div className="l-content">
    <div className="l-content m-report-page">
      <Row>
        <Column small={12}>
          <h2>
            <T _str="Analysis report" />
          </h2>
          <MapView
            page="report"
            options={{
              map: {
                minZoom: 2,
                maxZoom: 25,
                zoomControl: false,
              },
            }}
          />
          <Loader />

          <Legend />

          <LayerAnalysis responsiveCharts width={670} />

          <a href="http://resilienceatlas.org/" className="logo">
            <span />
          </a>
        </Column>
      </Row>
    </div>
  </div>
);

ReportPage.Layout = (page) => <ReportLayout pageTitle="Report">{page}</ReportLayout>;

export default ReportPage;
