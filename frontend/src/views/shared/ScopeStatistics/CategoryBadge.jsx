import React from 'react';

const CATEGORY_COLORS = {
  Exceeding: '#2ecc71',
  Achieving: '#f39c12',
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
