import React, { useCallback, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Combobox } from '@headlessui/react';
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

type Place = {
  description: string;
  place_id: string;
};

const googleAPILoader = new Loader({
  apiKey: process.env.NEXT_PUBLIC_GOOGLE_API_KEY,
  version: 'weekly',
});

let autocompleteService: google.maps.places.AutocompleteService = null;
let geocoderService: google.maps.Geocoder = null;

googleAPILoader.load().then(async () => {
  const { AutocompleteService } = (await google.maps.importLibrary(
    'places',
  )) as google.maps.PlacesLibrary;
  const { Geocoder } = (await google.maps.importLibrary(
    'geocoding',
  )) as google.maps.GeocodingLibrary;
  autocompleteService = new AutocompleteService();
  geocoderService = new Geocoder();
});

/**
 * Only works on the client side because of window dependency
 */
const SearchArea: React.FC<SearchAreaProps> = ({ fitBounds, onAfterChange }) => {
  const t = useT();
  const locale = useLocale();
  const [selectedPlace, setSelectedPlace] = useState<Place>(null);
  const [query, setQuery] = useState('');
  const [searchTerm] = useDebounce(query, 1000);

  const currentLocale = locale && locale !== '' ? locale : 'en';

  const { data: places, isLoading } = useQuery<Place[]>(
    ['places'],
    () => {
      const request = autocompleteService
        .getPlacePredictions({
          input: searchTerm,
          language: currentLocale, // Default to English
        })
        .then((response: { predictions: Place[] }) => response?.predictions);
      return request;
    },
    {
      enabled: !!searchTerm && searchTerm.length > 0,
      refetchOnMount: false,
      refetchOnWindowFocus: false,
      refetchOnReconnect: false,
    },
  );

  const handleInputChange = useCallback(
    (event: React.FormEvent<HTMLInputElement>) => {
      setQuery(event.currentTarget.value);
    },
    [setQuery],
  );

  const handleChange = useCallback(
    async (place: Place) => {
      setSelectedPlace(place);
      if (place && geocoderService) {
        // Requesting geometry given a place id
        try {
          const { results } = await geocoderService.geocode({ placeId: place.place_id });
          const geometry = results[0].geometry;
          const boundsJSON = geometry.viewport.toJSON();
          const bounds: BBox = [
            boundsJSON.west,
            boundsJSON.south,
            boundsJSON.east,
            boundsJSON.north,
          ];
          const polygon = bboxPolygon(bounds);
          fitBounds(polygon);
          onAfterChange();
        } catch (error) {
          console.error(error);
        }
      }
    },
    [fitBounds, onAfterChange],
  );

  return (
    <div className="m-search-map">
      <Combobox value={selectedPlace} by="place_id" onChange={handleChange} nullable>
        <Combobox.Input
          onChange={handleInputChange}
          displayValue={(place: Place) => place?.description}
          className="search-combobox-input"
          placeholder={t('Search by country, city, town, coordinates')}
        />
        <div className="search-combobox-options">
          <Combobox.Options>
            {places?.map((place) => (
              <Combobox.Option key={place.place_id} value={place} as={React.Fragment}>
                {({ active }) => (
                  <li className={cx({ 'is-active': active })}>
                    <span className="option-label">
                      <HighlightedText text={place.description} highlight={query} />
                    </span>
                  </li>
                )}
              </Combobox.Option>
            ))}
            {places?.length === 0 && (
              <div className="search-combobox-message">
                <T _str="No results found" />
              </div>
            )}
            {!places && isLoading && (
              <div className="search-combobox-message">
                <T _str="Loading..." />
              </div>
            )}
          </Combobox.Options>
        </div>
      </Combobox>
    </div>
  );
};

export default SearchArea;
