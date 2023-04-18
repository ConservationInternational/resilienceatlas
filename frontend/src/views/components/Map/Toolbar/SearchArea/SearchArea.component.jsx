import React from 'react';
import cx from 'classnames';
import { T } from '@transifex/react';

import { useSearch } from 'utilities/hooks';

const SearchArea = ({ fitBounds, countries, translations }) => {
  const { searchInput, result, noResults } = useSearch('search', countries, {
    valueKey: 'name',
    onSelect: ({ geometry }) => {
      fitBounds(JSON.parse(geometry));
    },
  });

  return (
    <div className="m-search-map" id="searchBox">
      <input
        id="searchMap"
        placeholder={translations && translations['Search area']}
        type="search"
        {...searchInput}
      />
      <div className="search-box" id="searchContent">
        <div id="search-tpl">
          <div className={cx('search-content', { searching: !!searchInput.value })}>
            <div className="search-result" />
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

              {noResults && (
                <div className="no-results">
                  <T _str="No results" />
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default SearchArea;
