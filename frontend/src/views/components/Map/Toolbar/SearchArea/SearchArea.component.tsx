import React, { useCallback, useState, useRef } from 'react';
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

type PlacePrediction = {
  placeId: string;
  text: {
    text: string;
    toString: () => string;
  };
  toPlace: () => google.maps.places.Place;
};

type Place = {
  place_id: string | null;
  description: string | null;
  latLngString?: string;
  // Store the original prediction for fetching place details
  _prediction?: PlacePrediction;
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

let geocoderService: google.maps.Geocoder = null;
let placesLibraryLoaded = false;
let googleMapsLoadFailed = false;

// Only load if we have a valid API key
if (googleAPILoader) {
  googleAPILoader
    .load()
    .then(async () => {
      // Load the places library (required for AutocompleteSuggestion)
      await google.maps.importLibrary('places');
      placesLibraryLoaded = true;
      const { Geocoder } = (await google.maps.importLibrary(
        'geocoding',
      )) as google.maps.GeocodingLibrary;
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

  // Use a ref to store the session token for billing purposes
  const sessionTokenRef = useRef<google.maps.places.AutocompleteSessionToken | null>(null);

  const currentLocale = locale && locale !== '' ? locale : 'en';

  const { data, isLoading } = useQuery<Place[]>({
    queryKey: ['places', searchTerm],
    queryFn: async () => {
      if (!placesLibraryLoaded) {
        return [];
      }

      // Create a new session token if we don't have one
      if (!sessionTokenRef.current) {
        sessionTokenRef.current = new google.maps.places.AutocompleteSessionToken();
      }

      const request: google.maps.places.AutocompleteRequest = {
        input: searchTerm,
        language: currentLocale,
        sessionToken: sessionTokenRef.current,
      };

      try {
        const { suggestions } =
          await google.maps.places.AutocompleteSuggestion.fetchAutocompleteSuggestions(request);

        // Convert suggestions to Place format for compatibility
        return suggestions
          .filter((suggestion) => suggestion.placePrediction)
          .map((suggestion) => {
            const prediction = suggestion.placePrediction;
            return {
              place_id: prediction.placeId,
              description: prediction.text.text,
              _prediction: prediction,
            } as Place;
          });
      } catch (error) {
        console.warn('Failed to fetch autocomplete suggestions:', error);
        return [];
      }
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

  const places = data || [];

  const handleInputChange = useCallback(
    (event: React.FormEvent<HTMLInputElement>) => {
      setQuery(event.currentTarget.value);
    },
    [setQuery],
  );

  const handleChange = useCallback(
    async (place: Place) => {
      setSelectedPlace(place);

      // Reset session token after a selection is made (for proper billing)
      sessionTokenRef.current = null;

      // Requesting geometry given coordinates
      if (isCoordinates(place?.latLngString)) {
        // Skip geocoding if service is not available
        if (!geocoderService) {
          console.warn('Geocoder service not available');
          return;
        }
        const { longitude, latitude } = place.latLngString.match(COORDINATES_REGEX).groups;
        const { results } = await geocoderService.geocode({
          location: { lat: Number(latitude), lng: Number(longitude) },
        });
        fitBounds(fromGeometryToPolygonBounds(results[0].geometry));
        onAfterChange();
      }

      // Requesting geometry using the new Place API
      else if (place?._prediction) {
        try {
          const placeObject = place._prediction.toPlace();
          await placeObject.fetchFields({
            fields: ['viewport', 'location'],
          });

          if (placeObject.viewport) {
            const boundsJSON = placeObject.viewport.toJSON();
            const bounds: BBox = [
              boundsJSON.west,
              boundsJSON.south,
              boundsJSON.east,
              boundsJSON.north,
            ];
            fitBounds(bboxPolygon(bounds));
          } else if (placeObject.location) {
            // Fallback: create a small viewport around the location
            const lat = placeObject.location.lat();
            const lng = placeObject.location.lng();
            const bounds: BBox = [lng - 0.01, lat - 0.01, lng + 0.01, lat + 0.01];
            fitBounds(bboxPolygon(bounds));
          }
          onAfterChange();
        } catch (error) {
          console.warn('Failed to fetch place details:', error);
          // Fallback to geocoder if new API fails
          if (geocoderService && place.place_id) {
            const { results } = await geocoderService.geocode({ placeId: place.place_id });
            fitBounds(fromGeometryToPolygonBounds(results[0].geometry));
            onAfterChange();
          }
        }
      }

      // Fallback: Requesting geometry given a place id using geocoder
      else if (place?.place_id) {
        if (!geocoderService) {
          console.warn('Geocoder service not available');
          return;
        }
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
            {places.map((place) => (
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
            {places.length === 0 && !isLoading && (
              <div className="search-combobox-message">
                <T _str="No results found" />
              </div>
            )}
            {places.length === 0 &&
              isLoading &&
              !isCoordinates(searchTerm) &&
              !isNumber(searchTerm) && (
                <div className="search-combobox-message">
                  <T _str="Loading..." />
                </div>
              )}
            {places.length === 0 && isCoordinates(searchTerm) && (
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
