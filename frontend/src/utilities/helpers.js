import L from 'leaflet';
import history from '../history';

/**
 * @param  {string} key key to sort on
 * @param  {boolean} desc=false to sort in descending order
 *
 * @returns {function} to be inserted in .sort method
 */
export const sortBy =
  (key, desc = false) =>
  (a, b) => {
    if (a[key] > b[key]) return desc ? -1 : 1;
    if (a[key] < b[key]) return desc ? 1 : -1;
    return 0;
  };

/**
 * @param  {function} onClick click handler to be bound to element
 *
 * @returns  {object} object of properties to semantically hanlde click
 */
export const clickable = (onClick) => ({
  onClick,
  tabIndex: 0,
  role: 'button',
  onKeyPress: (e) => (e.keyCode === 13 || e.charCode === 13) && onClick(),
});

/**
 * @param  {array} array input array
 *
 * @returns  {array} array of only unique values
 */
export const uniq = (array) => Array.from(new Set(array));

/**
 * Deep merges two objets.
 * @param  {Object} object destination object
 * @param  {Object} source source obejct
 *
 * @returns {Object} new object
 */
export const merge = (object, source) => {
  if (object === source) return object;

  const newValue = {
    ...object,
    ...source,
  };

  Object.entries(source).forEach(([key, value]) => {
    if (object[key] && typeof object[key] === 'object') {
      newValue[key] = merge(object[key], value);
    } else {
      newValue[key] = value;
    }
  });

  return newValue;
};

export const swapLatLng = (geojson) =>
  L.geoJSON(geojson, {
    coordsToLatLng: (coords) => new L.LatLng(coords[0], coords[1], coords[2]),
  }).toGeoJSON();

export const formatNumber = ({ value, locale = 'en', formatFrom = 10000, ...rest }) => {
  if (value < formatFrom) {
    return new Intl.NumberFormat(locale, rest).format(value);
  }

  const intl = new Intl.NumberFormat(locale, {
    minimumFractionDigits: 0,
    maximumFractionDigits: 1,
    ...rest,
  });

  if (value >= 1e9) {
    return `${intl.format(value / 1e9)}B`;
  }

  if (value >= 1e6) {
    return `${intl.format(value / 1e6)}M`;
  }

  if (value >= 1e3) {
    return `${intl.format(value / 1e3)}K`;
  }

  return 0;
};

export function getNestedChildren(arr, ancestry) {
  const out = [];

  arr.forEach((item) => {
    // eslint-disable-next-line eqeqeq
    if (item.ancestry == ancestry) {
      const children = getNestedChildren(arr, item.id);

      if (children.length) {
        item.children = children;
      }
      out.push(item);
    }
  });

  return out;
}

export const download = (content, fileName, mimeType = 'application/octet-stream') => {
  const link = document.createElement('a');

  if (navigator.msSaveBlob) {
    // IE10
    navigator.msSaveBlob(
      new Blob([content], {
        type: mimeType,
      }),
      fileName,
    );
  } else if (URL && 'download' in link) {
    // html5 a[download]
    link.href = URL.createObjectURL(
      new Blob([content], {
        type: mimeType,
      }),
    );
    link.setAttribute('download', fileName);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  } else {
    history.push(`data:application/octet-stream,${encodeURIComponent(content)}`); // only this mime type is supported
  }
};

export const removeHtmlTags = (str) => {
  if (!str || !str.toString) return str;
  return str.toString().replace(/<\/?[a-z]+>/gi, '');
};
