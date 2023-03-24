import React, { useEffect, useMemo } from 'react';
import DangerousHTML from 'react-dangerous-html';
import Iframe from 'react-iframe';
import Legend from 'views/components/Legend';
import qs from 'qs';

// TODO: get rid of IFrame and use Map Component
// It requires to refactor map to use redux instead of url in all cases
// And to add separate mapper, to store all needed variables from redux
// in url only on map page

const STATIC_JOURNEYS = process.env.NEXT_PUBLIC_STATIC_JOURNEYS === 'true';

const StaticEmbed = (props) => {
  const {
    loadLayers,
    loadCountries,
    layersLoaded,
    countriesLoaded,
    countries,
    theme,
    mapUrl,
    btnUrl,
    maskSql,
    aside,
    currentStep,
    countryName,
    setActiveLayer,
  } = props;

  useEffect(() => {
    if (!layersLoaded) loadLayers();
    if (!countriesLoaded) loadCountries();
  }, []);

  useEffect(() => {
    const mapString = mapUrl.split('?')[1];
    const mapData = qs.parse(mapString);
    const layerData = JSON.parse(mapData.layers);
    const layerDataIds = layerData.map((l) => l.id);

    setActiveLayer(layerDataIds);
  }, [mapUrl]);
  const countryInfo =
    countries.find((c) => c.name.toLowerCase() === countryName.toLowerCase()) || {};

  const embedParams = useMemo(() => {
    const params = new URLSearchParams();

    params.set('journeyMap', true);
    params.set('maskSql', maskSql);

    if (countriesLoaded && countryInfo.geometry) {
      params.set('geojson', countryInfo.geometry);
    }

    return params.toString();
  }, [countriesLoaded, countryInfo.geometry, maskSql]);
  return (
    <div className={`m-journey--embed--light ${theme}`}>
      <div className="embebed-map">
        <Iframe src={`${mapUrl}&${embedParams}`} />
        <a
          href={btnUrl}
          target="_blank"
          rel="noopener noreferrer"
          data-step={currentStep}
          className="btn-check-it"
        >
          View on map
        </a>
      </div>
      <article className="side-bar">
        <div className="wrapper">
          <article>
            <DangerousHTML html={aside} />
            <Legend />
            <footer>
              <p>INSIGHTS PROVIDED BY CONSERVATION INTERNATIONAL</p>
            </footer>
          </article>
        </div>
      </article>
    </div>
  );
};

const Embed = (props) => {
  const {
    loadLayers,
    loadCountries,
    layersLoaded,
    countriesLoaded,
    countries,
    theme,
    embedded_map_url: mapUrl,
    map_url: btnUrl,
    mask_sql: maskSql,
    source,
    content,
    currentStep,
    countryName,
    setActiveLayer,
  } = props;

  useEffect(() => {
    if (!layersLoaded) loadLayers();
    if (!countriesLoaded) loadCountries();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    const mapString = mapUrl.split('?')[1];
    const mapData = qs.parse(mapString);
    const layerData = JSON.parse(mapData.layers);
    const layerDataIds = layerData.map((l) => l.id);

    setActiveLayer(layerDataIds);
  }, [mapUrl, setActiveLayer]);
  const countryInfo =
    countries.find((c) => c.name.toLowerCase() === countryName.toLowerCase()) || {};

  const embedParams = useMemo(() => {
    const params = new URLSearchParams();

    params.set('journeyMap', true);
    params.set('maskSql', maskSql);

    if (countriesLoaded && countryInfo.geometry) {
      params.set('geojson', countryInfo.geometry);
    }

    return params.toString();
  }, [countriesLoaded, countryInfo.geometry, maskSql]);
  return (
    <div className={`m-journey--embed--light ${theme}`}>
      <div className="embebed-map">
        <Iframe src={`${mapUrl}&${embedParams}`} />
        <a
          href={btnUrl}
          target="_blank"
          rel="noopener noreferrer"
          data-step={currentStep}
          className="btn-check-it"
        >
          View on map
        </a>
      </div>
      <article className="side-bar">
        <div className="wrapper">
          <article>
            <DangerousHTML html={content} />
            {/* TODO: Review if source is rendered correctly */}
            {source}
            <Legend />
            <footer>
              <p>INSIGHTS PROVIDED BY CONSERVATION INTERNATIONAL</p>
            </footer>
          </article>
        </div>
      </article>
    </div>
  );
};

Embed.defaultProps = {
  countryName: '',
};

export default STATIC_JOURNEYS ? StaticEmbed : Embed;
