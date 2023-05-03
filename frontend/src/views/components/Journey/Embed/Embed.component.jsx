import React, { useEffect, useMemo } from 'react';
import DangerousHTML from 'react-dangerous-html';
import Iframe from 'react-iframe';
import Legend from 'views/components/Legend';
import InfoWindow from 'views/components/InfoWindow';
import qs from 'qs';
import cx from 'classnames';
import { T } from '@transifex/react';
import { useRouter } from 'next/router';

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
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    const mapString = mapUrl.split('?')[1];
    const mapData = qs.parse(mapString);
    const layerData = JSON.parse(mapData.layers);
    const layerDataIds = layerData.map((l) => l.id);

    setActiveLayer(layerDataIds);
    // eslint-disable-next-line react-hooks/exhaustive-deps
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
    layersLocaleLoaded,
    countriesLoaded,
    countries,
    theme,
    embedded_map_url: mapUrl,
    map_url: btnUrl,
    mask_sql: maskSql,
    source,
    content,
    title,
    subtitle,
    currentStep,
    countryName,
    setActiveLayer,
    isLastStep,
  } = props;
  const { locale } = useRouter();
  useEffect(() => {
    if (!layersLoaded || layersLocaleLoaded !== locale) {
      loadLayers(locale);
    }
    if (!countriesLoaded) loadCountries();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [locale]);
  useEffect(() => {
    const mapString = mapUrl.split('?')[1];
    if (mapString) {
      const mapData = mapString && qs.parse(mapString);
      const layerData = mapData && JSON.parse(mapData.layers);
      const layerDataIds = layerData?.map((l) => l.id);

      setActiveLayer(layerDataIds);
    }
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

  const provideAbsoluteOrRelativeUrl = (url) => {
    if (url.startsWith('http')) {
      return url.replace('resilienceatlas.org/', `resilienceatlas.org/${locale}/`);
    }
    return `/${locale}${url}`;
  };

  return (
    <div className={`m-journey--embed--light ${theme}`}>
      <article className="side-bar">
        <div className="wrapper">
          <article>
            <header>
              <h2>{title}</h2>
              <h3>{subtitle}</h3>
            </header>
            <section>
              <h1>{countryName}</h1>
              {content && <DangerousHTML html={content} className="content" />}
            </section>
            {/* TODO: Review if source is rendered correctly */}
            {source}
            <Legend />
            <InfoWindow />
            <footer>
              <p>
                <T _str="INSIGHTS PROVIDED BY CONSERVATION INTERNATIONAL" />
              </p>
            </footer>
          </article>
        </div>
      </article>
      <div className="embebed-map">
        <Iframe src={`${provideAbsoluteOrRelativeUrl(mapUrl)}&${embedParams}`} />
        <a
          href={provideAbsoluteOrRelativeUrl(btnUrl)}
          target="_blank"
          rel="noopener noreferrer"
          data-step={currentStep}
          className={cx('btn-check-it', { 'last-step': isLastStep })}
        >
          <T _str="View on map" />
        </a>
      </div>
    </div>
  );
};

Embed.defaultProps = {
  countryName: '',
};

export default STATIC_JOURNEYS ? StaticEmbed : Embed;
