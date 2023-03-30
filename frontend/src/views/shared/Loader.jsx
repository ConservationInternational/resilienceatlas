import React from 'react';
import PropTypes from 'prop-types';
import cx from 'classnames';

const Loader = ({ loading, text, inline }) => (
  <div className={cx('m-loader', { 'is-loading': loading, inline })}>{text}</div>
);

Loader.propTypes = {
  loading: PropTypes.bool,
  inline: PropTypes.bool,
  text: PropTypes.string,
};

Loader.defaultProps = {
  loading: false,
  inline: false,
  text: 'loading',
};

export default Loader;
