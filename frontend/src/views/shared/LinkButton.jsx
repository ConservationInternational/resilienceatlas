import React from 'react';

const LinkButton = ({ onClick, link = '#', children, ...props }) => (
  <a
    href={link}
    tabIndex="0"
    role="button"
    onClick={onClick}
    onKeyPress={e => (e.keyCode === 13 || e.which === 13) && onClick(e)}
    {...props}
  >
    {children}
  </a>
);

export default LinkButton;
