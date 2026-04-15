import React from 'react';

const CATEGORY_COLORS = {
  Achieving: '#2ecc71',
  'Not achieving': '#e74c3c',
};

const CategoryBadge = ({ value }) => {
  const color = CATEGORY_COLORS[value];

  return (
    <span
      className="category-badge"
      style={color ? { backgroundColor: color, color: '#fff' } : undefined}
    >
      {value}
    </span>
  );
};

export default CategoryBadge;
