import React from 'react';
import cx from 'classnames';

const Pagination: React.FC<{
  currentPage: number;
  numPages: number;
}> = ({ currentPage, numPages }) => {
  return (
    <div className="m-wizard-form__pagination">
      {[...Array(numPages)].map((_page, index) => {
        return (
          <span
            key={index}
            className={cx('m-wizard-form__pagination-item', {
              active: currentPage - 1 >= index,
            })}
          >
            <span className="m-wizard-form__pagination-item-number">{index + 1}</span>
          </span>
        );
      })}
    </div>
  );
};

export default Pagination;
