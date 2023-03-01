import React from 'react';
import Helmet from 'react-helmet';
import { Row, Column } from 'react-foundation';

import MapView from '@components/Map';
import Legend from '@components/Legend';
import { LayerAnalysis } from '@components/AnalysisPanel/AnalysisContent';

import Loader from '@shared/Loader';

const Report = () => (
  <>
    <Helmet title="Analysis report" />

    <div className="l-content m-report-page">
      <Row>
        <Column small={12}>
          <h2>Analysis report</h2>
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
  </>
);

export default Report;
