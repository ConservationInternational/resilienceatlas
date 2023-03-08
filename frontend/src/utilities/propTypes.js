import React from 'react';

export const componentType = C => {
  let validate = (required, props, propName, componentName) => {
    const prop = props[propName];

    let error = null;

    if (required && React.Children.count(prop) === 0) {
      error = new Error(`\`${componentName}\` should have at least one \`${C.name}\` inside.`);
    }

    React.Children.forEach(prop, child => {
      if (child.type !== C) {
        error = new Error(`\`${componentName}\` children should be of type \`${C.name}\``);
      }
    });

    return error;
  };

  validate = validate.bind(null, false);
  validate.isRequired = validate.bind(null, true);

  return validate;
};
