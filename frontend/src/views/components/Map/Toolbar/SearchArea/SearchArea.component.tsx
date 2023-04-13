import React, { useCallback, useState } from 'react';
import cx from 'classnames';
import { Combobox } from '@headlessui/react';

import HighlightedText from 'views/components/HighlightedText';

type Country = {
  name: string;
  bbox: string;
  iso: string;
  geometry: string;
};

type SearchAreaProps = {
  fitBounds: (bounds: number[]) => void;
  countries: Country[];
};

const SearchArea: React.FC<SearchAreaProps> = ({ fitBounds, countries }) => {
  const [selectedCountry, setSelectedCountry] = useState(null);
  const [query, setQuery] = useState('');

  // Method to filter countries by name
  const filteredCountries =
    query === ''
      ? countries
      : countries.filter(({ name }) => {
          return name.toLowerCase().includes(query.toLowerCase());
        });

  const handleInputChange = useCallback(
    (event: React.FormEvent<HTMLInputElement>) => {
      setQuery(event.currentTarget.value);
    },
    [setQuery],
  );

  const handleChange = useCallback(
    (country: Country) => {
      setSelectedCountry(country);
      if (country) fitBounds(JSON.parse(country.geometry));
    },
    [fitBounds, setSelectedCountry],
  );

  return (
    <div className="m-search-map">
      <Combobox value={selectedCountry} by="iso" onChange={handleChange} nullable>
        <Combobox.Input
          onChange={handleInputChange}
          displayValue={(country: Country) => country?.name}
          className="search-combobox-input"
        />
        <div className="search-combobox-options">
          <Combobox.Options>
            {filteredCountries.map((country) => (
              <Combobox.Option key={country.iso} value={country} as={React.Fragment}>
                {({ active }) => (
                  <li className={cx({ 'is-active': active })}>
                    <span className="option-label">
                      <HighlightedText text={country.name} highlight={query} />
                    </span>
                  </li>
                )}
              </Combobox.Option>
            ))}
          </Combobox.Options>
        </div>
      </Combobox>
    </div>
  );
};

export default SearchArea;
