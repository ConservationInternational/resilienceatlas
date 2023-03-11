import type { FC } from 'react';
import React, { useState, useCallback, useEffect, useMemo } from 'react';
import qs from 'qs';
import cx from 'classnames';
import { useDropzone } from 'react-dropzone';

import Tabs from 'views/shared/Tabs';
import { useDownloadableReport } from 'utilities/hooks/downloadableReport';
import { useSearch } from 'utilities';
import { TABS } from '../Sidebar';

import { LayerAnalysis, PredictiveModelAnalysis } from './AnalysisContent';

const ACCEPTED_EXTENSIONS = ['.json', '.geojson'];

interface P {
  drawing: boolean;
  geojson: L.GeoJSON;
}

export const AnalysisPanel: FC<P> = ({
  // actions
  loadCountries,
  setDrawing,
  setGeojson,
  setISO,
  toggle,
  // data
  countriesLoaded,
  drawing,
  router,
  countries,
  geojson,
  iso,
}) => {
  const sidebarTab = useMemo(
    () => qs.parse(router.query, { ignoreQueryPrefix: true }).tab,
    [location],
  );
  useEffect(() => {
    if (!countriesLoaded) loadCountries();
  }, []);

  const [tab, setTab] = useState(geojson && !iso ? 'shape' : 'region');
  const switchTab = useCallback(
    (e) => {
      const newTab = e.target.dataset.tab;

      if (tab !== newTab) {
        setTab(newTab);
        setGeojson(null);
      }
    },
    [tab],
  );

  const toggleDrawing = useCallback(() => {
    setDrawing(!drawing);
  }, [drawing]);

  const resetAnalytics = useCallback(() => {
    setGeojson(null);
    setISO(null);
  }, []);

  const onDrop = useCallback(([file]) => {
    const regex = new RegExp(`((${ACCEPTED_EXTENSIONS.join('|')}))$`);

    if (!regex.test(file.name)) {
      window.alert('Only .json and .geojson files are accepted. Please select a different file.');
      return;
    }

    const reader = new FileReader();

    reader.onload = (e) => {
      try {
        const json = JSON.parse(e.target.result);

        // Simple check to validate the format of the file
        const types = [
          'Feature',
          'FeatureCollection',
          'Point',
          'MultiPoint',
          'LineString',
          'MultiLineString',
          'Polygon',
          'MultiPolygon',
          'GeometryCollection',
        ];
        if (!json.type || !types.includes(json.type)) {
          throw new Error('The file doesn\'t have a top-level "type" property correctly defined.');
        }

        setGeojson(json);
      } catch (err) {
        console.error(err);
        window.alert("The file can't be read. Make sure it's the GeoJSON is valid.");
      }
    };

    reader.readAsText(file);
  }, []);
  const { getRootProps, getInputProps, isDragActive } = useDropzone({ onDrop });
  const { searchInput, result, noResults } = useSearch('search', countries, {
    valueKey: 'name',
    onSelect: ({ iso }) => setISO(iso),
  });
  const downloadableReport = useDownloadableReport();

  return (
    <div className="m-sidebar analysis-panel" id="analysisPanelView">
      <div className="title">
        <button
          className="btn-analysis-panel-contract"
          type="button"
          onClick={toggle}
          aria-label="Contract analysis panel"
        />
        Analysis
      </div>
      <div className="content">
        <div id="analysisSelectorsView" className="m-analysis-selectors">
          <div className="m-analysis-model">
            <div className="tabs js-tabs">
              <button
                type="button"
                className={cx({ '-active': tab === 'region' })}
                data-tab="region"
                onClick={switchTab}
              >
                Country or region
              </button>
              <button
                type="button"
                className={cx({ '-active': tab === 'shape' })}
                data-tab="shape"
                onClick={switchTab}
              >
                Draw or upload shape
              </button>
            </div>

            {!(geojson || iso) ? (
              <Tabs activeTab={tab} renderActiveOnly>
                <Tabs.Pane name="region">
                  <p>Select a country or region from the list below.</p>
                  <div className="m-search-analysis">
                    <svg className="icon-search">
                      <use xmlnsXlink="http://www.w3.org/1999/xlink" xlinkHref="#icon-search" />
                    </svg>
                    <input
                      className="searchAnalysis"
                      placeholder="Type country"
                      type="search"
                      {...searchInput}
                    />
                    <div className="analysisSearchContent search-box visible">
                      <div className="search-content searching">
                        <div className="search-suggestions">
                          <ul>
                            {result.map((item, key) => {
                              const { label, name, iso, selected, optionProps } = item;

                              const isSelected = selected % result.length === key;

                              return (
                                <li
                                  key={iso}
                                  className={cx('search-area', {
                                    selected: isSelected,
                                  })}
                                  title={name}
                                  {...optionProps}
                                >
                                  <span className="name">{label}</span>
                                </li>
                              );
                            })}
                          </ul>
                        </div>
                      </div>
                      {noResults && <div>No results</div>}
                    </div>
                  </div>
                </Tabs.Pane>
                <Tabs.Pane name="shape">
                  <p>Draw on the map the area you want to analyze or pick a file.</p>
                  <div className="buttons">
                    <button
                      type="button"
                      className="btn -primary js-toggle-draw"
                      onClick={toggleDrawing}
                    >
                      {drawing ? 'Cancel' : 'Start drawing'}
                    </button>
                    <br />
                    or
                    <br />
                    <button
                      {...getRootProps()}
                      type="button"
                      className={cx('btn -dotted', { '-active': isDragActive })}
                    >
                      {isDragActive
                        ? 'Drop here'
                        : 'Click here to select a GeoJSON file or drag and drop the file here'}
                    </button>
                    <input {...getInputProps()} hidden accept=".json,.geojson" />
                  </div>
                </Tabs.Pane>
              </Tabs>
            ) : (
              <>
                {sidebarTab === TABS.MODELS ? <PredictiveModelAnalysis /> : <LayerAnalysis />}
                <div className="buttons">
                  <a className="btn -primary" {...downloadableReport}>
                    Download PDF report
                  </a>
                  <button type="button" className="btn -secondary" onClick={resetAnalytics}>
                    Reset the analysis
                  </button>
                  <br />
                  <a
                    className="btn -primary"
                    href="https://www.resilienceatlas.org/shinny-app"
                    target="_blank"
                    rel="noreferrer"
                  >
                    Go to Shinny App
                  </a>
                </div>
              </>
            )}
          </div>
        </div>
        <div id="analysisView" className="m-analysis" />
      </div>
    </div>
  );
};
