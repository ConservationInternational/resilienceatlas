import React, { useEffect, useMemo } from 'react';
import DangerousHTML from 'react-dangerous-html';
import Iframe from 'react-iframe';
import Legend from 'views/components/Legend';
import InfoWindow from 'views/components/InfoWindow';
import qs from 'qs';
import cx from 'classnames';
import { T } from '@transifex/react';
import { useRouter } from 'next/router';
import { getSubdomainFromURL } from 'utilities/getSubdomain';
import { URL_PERSISTED_KEYS } from 'state/modules/layers';

// TODO: get rid of IFrame and use Map Component
// It requires to refactor map to use redux instead of url in all cases
// And to add separate mapper, to store all needed variables from redux
// in url only on map page

const getLayerData = (mapUrl) => {
  const mapString = mapUrl.split('?')[1];
  if (mapString) {
    const mapData = mapString && qs.parse(mapString);
    return mapData && JSON.parse(mapData.layers);
  }
  return null;
};

const provideAbsoluteOrRelativeUrl = (url, locale) => {
  if (url.startsWith('http')) {
    return url.replace('resilienceatlas.org/', `resilienceatlas.org/${locale}/`);
  }
  return `/${locale}${url}`;
};

const Embed = (props) => {
  const {
    loadLayers,
    loadCountries,
    layersLoaded,
    layersLocaleLoaded,
    layersLoadedSubdomain,
    layersById,
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

  // Load layers and countries when needed
  useEffect(() => {
    const siteScope = mapUrl.startsWith('http') && getSubdomainFromURL(mapUrl);
    const subdomainIsDifferentThanLoaded =
      layersLoadedSubdomain !== siteScope && (layersLoadedSubdomain || siteScope);
    if (!layersLoaded || layersLocaleLoaded !== locale || subdomainIsDifferentThanLoaded) {
      loadLayers(locale, siteScope);
    }
    if (!countriesLoaded) loadCountries();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [locale, mapUrl]);

  // Update map url with the new selected params on the legend
  const mapURLWithParams = useMemo(() => {
    const currentURL = new URL(mapUrl);
    const layers = currentURL.searchParams.get('layers');
    if (!layers) return mapUrl;

    const parsedLayers = layers && JSON.parse(layers);
    const updatedLayers = parsedLayers.reduce((acc, layer, index) => {
      const layerUpdatedData = layersById[layer.id];
      if (layerUpdatedData) {
        URL_PERSISTED_KEYS.forEach((key) => {
          if (layerUpdatedData[key]) {
            acc[index][key] = layerUpdatedData[key];
          }
        });
      }
      return acc;
    }, parsedLayers);
    currentURL.searchParams.set('layers', JSON.stringify(updatedLayers));
    return currentURL ? currentURL.toString() : mapUrl;
  }, [mapUrl, layersById]);

  // Set active layer
  useEffect(() => {
    const layerData = getLayerData(mapUrl);
    if (layerData) {
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
        <Iframe src={`${provideAbsoluteOrRelativeUrl(mapURLWithParams, locale)}&${embedParams}`} />
        <a
          href={provideAbsoluteOrRelativeUrl(btnUrl, locale)}
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

export default Embed;
