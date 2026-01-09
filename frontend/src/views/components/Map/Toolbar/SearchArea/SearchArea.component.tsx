import React, { useCallback, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Combobox, ComboboxInput, ComboboxOption, ComboboxOptions } from '@headlessui/react';
import { useDebounce } from 'use-debounce';
import cx from 'classnames';
import bboxPolygon from '@turf/bbox-polygon';
import { useT, T, useLocale } from '@transifex/react';
import { Loader } from '@googlemaps/js-api-loader';

import HighlightedText from 'views/components/HighlightedText';

import type { BBox } from 'geojson';

type SearchAreaProps = {
  fitBounds: (bounds: unknown) => void;
  onAfterChange: () => void;
};

type Place = google.maps.places.AutocompletePrediction & {
  latLngString?: string;
};

// Only initialize Google Maps if we have a valid API key
const googleApiKey = process.env.NEXT_PUBLIC_GOOGLE_API_KEY;
const hasValidApiKey = googleApiKey && googleApiKey.length > 0 && googleApiKey !== 'test_api_key';

let googleAPILoader: Loader | null = null;
if (hasValidApiKey) {
  googleAPILoader = new Loader({
    apiKey: googleApiKey,
    version: 'weekly',
  });
}

let autocompleteService: google.maps.places.AutocompleteService = null;
let geocoderService: google.maps.Geocoder = null;
let googleMapsLoadFailed = false;

// Only load if we have a valid API key
if (googleAPILoader) {
  googleAPILoader
    .load()
    .then(async () => {
      const { AutocompleteService } = (await google.maps.importLibrary(
        'places',
      )) as google.maps.PlacesLibrary;
      const { Geocoder } = (await google.maps.importLibrary(
        'geocoding',
      )) as google.maps.GeocodingLibrary;
      autocompleteService = new AutocompleteService();
      geocoderService = new Geocoder();
    })
    .catch((error) => {
      console.warn('Google Maps API failed to load:', error.message);
      googleMapsLoadFailed = true;
    });
}

const COORDINATES_REGEX =
  /^(?<longitude>-?\d{1,}(\.\d{1,})?)(\s{1,}|\s{0,},\s{0,})(?<latitude>-?\d{1,}(\.\d{1,})?)$/;

const isCoordinates = (keyword: string) => COORDINATES_REGEX.test(keyword);

const fromGeometryToPolygonBounds = (geometry) => {
  const boundsJSON = geometry.viewport.toJSON();
  const bounds: BBox = [boundsJSON.west, boundsJSON.south, boundsJSON.east, boundsJSON.north];
  return bboxPolygon(bounds);
};

const isNumber = (value: string): boolean => !Number.isNaN(Number(value));

/**
 * Only works on the client side because of window dependency
 */
const SearchArea: React.FC<SearchAreaProps> = ({ fitBounds, onAfterChange }) => {
  const t = useT();
  const locale: string = useLocale();
  const [selectedPlace, setSelectedPlace] = useState<Place>(null);
  const [query, setQuery] = useState<string>('');
  const [searchTerm] = useDebounce(query, 300);

  const currentLocale = locale && locale !== '' ? locale : 'en';

  const { data, isLoading } = useQuery<google.maps.places.AutocompleteResponse>({
    queryKey: ['places', searchTerm],
    queryFn: () => {
      if (!autocompleteService) {
        return Promise.resolve({ predictions: [] });
      }
      const request = autocompleteService.getPlacePredictions({
        input: searchTerm,
        language: currentLocale, // Default to English
      });
      return request;
    },
    // Only fetch if the search term is not empty, is not a number, is not coordinates, and Google Maps is available
    enabled:
      !!searchTerm &&
      searchTerm.length > 0 &&
      !isCoordinates(searchTerm) &&
      !isNumber(searchTerm) &&
      hasValidApiKey &&
      !googleMapsLoadFailed,
    refetchOnMount: false,
    refetchOnWindowFocus: false,
    refetchOnReconnect: false,
  });

  const { predictions: places } = data || {};

  const handleInputChange = useCallback(
    (event: React.FormEvent<HTMLInputElement>) => {
      setQuery(event.currentTarget.value);
    },
    [setQuery],
  );

  const handleChange = useCallback(
    async (place: Place) => {
      setSelectedPlace(place);

      // Skip geocoding if service is not available
      if (!geocoderService) {
        console.warn('Geocoder service not available');
        return;
      }

      // Requesting geometry given coordinates
      if (isCoordinates(place?.latLngString)) {
        const { longitude, latitude } = place.latLngString.match(COORDINATES_REGEX).groups;
        const { results } = await geocoderService.geocode({
          location: { lat: Number(latitude), lng: Number(longitude) },
        });
        fitBounds(fromGeometryToPolygonBounds(results[0].geometry));
        onAfterChange();
      }

      // Requesting geometry given a place id
      else if (place?.place_id) {
        const { results } = await geocoderService.geocode({ placeId: place.place_id });
        fitBounds(fromGeometryToPolygonBounds(results[0].geometry));
        onAfterChange();
      }
    },
    [fitBounds, onAfterChange],
  );

  return (
    <div className="m-search-map">
      <Combobox value={selectedPlace} by="place_id" onChange={handleChange}>
        <ComboboxInput
          onChange={handleInputChange}
          displayValue={(place: Place) => place?.description || place?.latLngString}
          className="search-combobox-input"
          placeholder={t('Search by country, city, town, coordinates')}
        />
        <div className="search-combobox-options">
          <ComboboxOptions>
            {places?.map((place) => (
              <ComboboxOption key={place.place_id} value={place} as={React.Fragment}>
                {({ focus }) => (
                  <li className={cx({ 'is-active': focus })}>
                    <span className="option-label">
                      <HighlightedText text={place.description} highlight={query} />
                    </span>
                  </li>
                )}
              </ComboboxOption>
            ))}
            {places?.length === 0 && !isLoading && (
              <div className="search-combobox-message">
                <T _str="No results found" />
              </div>
            )}
            {!places && isLoading && !isCoordinates(searchTerm) && !isNumber(searchTerm) && (
              <div className="search-combobox-message">
                <T _str="Loading..." />
              </div>
            )}
            {!places && isCoordinates(searchTerm) && (
              <ComboboxOption
                value={{ place_id: null, description: null, latLngString: searchTerm }}
              >
                <div className="search-combobox-input-coordinates">
                  <T
                    _str={'{enter} to navigate coordinates'}
                    enter={
                      <span>
                        <T _str="Enter" _comment="Enter to navigate coordinates" />
                      </span>
                    }
                    _comment="Enter to navigate coordinates"
                  />
                </div>
              </ComboboxOption>
            )}
            {isNumber(searchTerm) && (
              <div className="search-combobox-message">
                <p>
                  <T _str="Are you typing coordinates?" />
                </p>
                <p className="--highlighted">
                  <T _str="Try to follow one of these formats" />:
                </p>
                <ul>
                  <li className="--highlighted">
                    <strong>-3.7034, 40.4306</strong> (<T _str="comma and space" />)
                  </li>
                  <li className="--highlighted">
                    <strong>-3.7034,40.4306</strong> (<T _str="only comma" />)
                  </li>
                  <li className="--highlighted">
                    <strong>-3.7034 40.4306</strong> (<T _str="only space" />)
                  </li>
                </ul>
                <p>
                  (<T _str="Longitude, Latitude in decimal degrees" />)
                </p>
              </div>
            )}
          </ComboboxOptions>
        </div>
      </Combobox>
    </div>
  );
};

export default SearchArea;
