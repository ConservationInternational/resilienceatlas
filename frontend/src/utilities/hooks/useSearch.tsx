import React, { useMemo, useState, useCallback, useEffect } from 'react';
import { clickable } from '../helpers';
import { useInput } from './hooks';

/**
 * @deprecated The method should not be used
 */
export const useSearch = (
  name,
  data: Record<string, unknown>[],
  { valueKey = 'value', onSelect = (v) => v },
) => {
  const searchInput = useInput(name, '');
  const [selectedIndex, setSelectedIndex] = useState(0);

  const result = useMemo(() => {
    if (searchInput.value && searchInput.value.length > 0) {
      return data
        .map((d) => {
          const text = searchInput.value.toLowerCase();
          const value = d[valueKey] as string;
          const index = value.toLowerCase().replace(/-/gi, ' ').indexOf(text);

          if (index >= 0) {
            const start = value.substring(0, index);
            const substr = value.substring(index, index + text.length);
            const end = value.substring(index + text.length);

            return {
              ...d,
              label: (
                <div>
                  {start}
                  <span>{substr}</span>
                  {end}
                </div>
              ),

              selected: selectedIndex,
              optionProps: {
                ...clickable(onSelect.bind(this, d)),
              },
            };
          }

          return null;
        })
        .filter(Boolean);
    }
    return [];
  }, [searchInput.value, selectedIndex]);

  useEffect(() => {
    const $el: Element = document.querySelector('.selected');

    if ($el) {
      const elRect = $el.getBoundingClientRect();
      const parentRect = $el.parentElement.parentElement.getBoundingClientRect();
      if (elRect.top < parentRect.top || elRect.bottom > parentRect.bottom) {
        $el.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
      }
    }
  }, [selectedIndex]);

  const onKeyDown = useCallback(
    (e: KeyboardEvent) => {
      const code = e.keyCode || e.charCode;

      switch (code) {
        // Enter pressed
        case 13: {
          e.preventDefault();
          if (result.length) {
            onSelect(result[selectedIndex]);
            // temporary cleanup -> while analysis panel tabs not separated to another component
            searchInput.setValue('');
            setSelectedIndex(0);
          }
          break;
        }
        // Arrow up pressed
        case 38: {
          e.preventDefault();
          setSelectedIndex(Math.max(selectedIndex - 1, 0));
          break;
        }
        // Arrow down pressed
        case 40: {
          e.preventDefault();
          setSelectedIndex(Math.min(selectedIndex + 1, result.length - 1));
          break;
        }

        default:
          break;
      }
    },
    [selectedIndex, result.length],
  );

  useEffect(() => {
    if (selectedIndex > result.length) {
      setSelectedIndex(result.length);
    }
  }, [result.length]);

  return {
    searchInput: { ...searchInput, onKeyDown, autoComplete: 'off' },
    result,
    noResults: !!searchInput.value.length && !result.length,
  };
};
