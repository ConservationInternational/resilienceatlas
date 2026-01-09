import React from 'react';
import PropTypes from 'prop-types';
import cx from 'classnames';

const Loader = ({ loading = false, text = 'loading', inline = false }) => (
  <div className={cx('m-loader', { 'is-loading': loading, inline })}>{text}</div>
);

Loader.propTypes = {
  loading: PropTypes.bool,
  inline: PropTypes.bool,
  text: PropTypes.string,
};

export default Loader;
