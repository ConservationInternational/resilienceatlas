import React, { useCallback, useEffect, useMemo } from 'react';
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
import { absoluteOrRelativeUrlWithCurrentLocale } from 'utilities/helpers';
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

const Embed = (props) => {
  const {
    loadLayers,
    layersLoaded,
    layersLocaleLoaded,
    layersLoadedSubdomain,
    layersById,
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
  const { locale, locales } = useRouter();

  // Load layers and countries when needed
  useEffect(() => {
    const siteScope = mapUrl.startsWith('http') && getSubdomainFromURL(mapUrl);
    const subdomainIsDifferentThanLoaded =
      layersLoadedSubdomain !== siteScope && (layersLoadedSubdomain || siteScope);
    if (!layersLoaded || layersLocaleLoaded !== locale || subdomainIsDifferentThanLoaded) {
      loadLayers(locale, siteScope);
    }

    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [locale, mapUrl]);

  // Update map url with the new selected params on the legend
  const addParamsToUrl = useCallback((url, layersById) => {
    const isURLRelative = url && url.startsWith('/');
    const currentURL = new URL(url, isURLRelative ? window.location.origin : undefined);
    const parsedLayers = getLayerData(url);
    if (!parsedLayers) return url;

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
    if (!currentURL) return url;
    return isURLRelative ? `${currentURL.pathname}${currentURL.search}` : currentURL.toString();
  }, []);

  const mapURLWithParams = useMemo(
    () => addParamsToUrl(mapUrl, layersById),
    [addParamsToUrl, mapUrl, layersById],
  );

  const btnURLWithParams = useMemo(
    () => addParamsToUrl(btnUrl, layersById),
    [addParamsToUrl, btnUrl, layersById],
  );

  // Set active layer
  useEffect(() => {
    const layerData = getLayerData(mapUrl);
    if (layerData) {
      const layerDataIds = layerData?.map((l) => l.id);
      setActiveLayer(layerDataIds);
    }
  }, [mapUrl, setActiveLayer]);

  const embedParams = useMemo(() => {
    const params = new URLSearchParams();

    params.set('journeyMap', true);
    params.set('maskSql', maskSql);

    // TODO: We get a 431 error when we send the geojson. Headers too long.
    // We may think about a better way to display the geojson

    // const countryInfo =
    //   countries.find((c) => c.name.toLowerCase() === countryName.toLowerCase()) || {};

    // if (countriesLoaded && countryInfo.geometry) {
    //   params.set('geojson', countryInfo.geometry);
    // }

    return params.toString();
  }, [maskSql]);

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
            {source}
            <Legend isEmbed defaultEmbedURLLayerParams={getLayerData(mapUrl)} />
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
        <Iframe
          src={`${absoluteOrRelativeUrlWithCurrentLocale(
            mapURLWithParams,
            locale,
            locales,
          )}&${embedParams}`}
        />
        <a
          href={absoluteOrRelativeUrlWithCurrentLocale(btnURLWithParams, locale, locales)}
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
