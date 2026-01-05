import React from 'react';
import classNames from 'classnames';

type ColumnSize = 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12;

interface ColumnProps {
  children?: React.ReactNode;
  className?: string;
  small?: ColumnSize;
  medium?: ColumnSize;
  large?: ColumnSize;
}

interface RowProps {
  children?: React.ReactNode;
  className?: string;
}

/**
 * Row component - creates a flex container for columns
 */
export const Row: React.FC<RowProps> = ({ children, className }) => {
  return <div className={classNames('row', className)}>{children}</div>;
};

/**
 * Column component - responsive grid column using flexbox
 * Uses a 12-column grid system with breakpoints:
 * - small: 0px and up (mobile first)
 * - medium: 640px and up
 * - large: 1024px and up
 */
export const Column: React.FC<ColumnProps> = ({ children, className, small, medium, large }) => {
  const columnClasses = classNames(
    'column',
    small && `small-${small}`,
    medium && `medium-${medium}`,
    large && `large-${large}`,
    className,
  );

  return <div className={columnClasses}>{children}</div>;
};

export default { Row, Column };
