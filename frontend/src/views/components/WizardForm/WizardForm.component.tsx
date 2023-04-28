import type { ReactNode } from 'react';
import React, { Children, useState } from 'react';
import cx from 'classnames';

import Pagination from './Pagination/Pagination.component';

const WizardForm: React.FC<{
  title?: string;
  subtitle?: string;
  description?: string;
  submitButton?: string;
  onSubmit: (values) => void;
  children: unknown | unknown[];
  formSubmitted: boolean;
  outroComponent: unknown;
}> = (props) => {
  const {
    title,
    subtitle,
    description,
    submitButton,
    onSubmit,
    children,
    formSubmitted,
    outroComponent,
  } = props;

  // Initialized to the current page number, not array indexes
  const [currentPage, setCurrentPage] = useState(1);

  const handlePreviousPageClick = () => {
    setCurrentPage(currentPage - 1);
  };

  const handleNextPageClick = () => {
    setCurrentPage(currentPage + 1);
  };

  const handleSubmit = (values) => {
    if (!isLastPage) {
      handleNextPageClick();
    } else {
      onSubmit(values);
    }
  };

  // Todo Simao: Fix types
  const pagesComponents = Children.toArray(children as ReactNode[]) as React.ReactElement[];
  const currentPageComponent = pagesComponents[currentPage - 1];

  const numPages = pagesComponents.length;
  const isFirstPage = currentPage === 1;
  const isLastPage = currentPage == numPages;

  const Page = React.cloneElement(currentPageComponent, {
    showTitle: !isFirstPage,
    onPrevious: handlePreviousPageClick,
    onSubmit: handleSubmit,
    submitButton,
    isFirstPage,
    isLastPage,
  });

  const Outro = outroComponent as React.ElementType;
  const displayOutro = formSubmitted && outroComponent;
  const displayPage = !displayOutro;

  return (
    <div
      className={cx('m-wizard-form', {
        'm-wizard-form--background-image': formSubmitted,
      })}
    >
      <div className="m-wizard-form__header">
        <button type="button" className="btn btn-primary">
          {/* TODO SIMAO: Translate */}
          Go back to map
        </button>
      </div>
      {displayPage && (
        <>
          {numPages > 1 && <Pagination currentPage={currentPage} numPages={numPages} />}
          <div className="m-wizard-form__wrapper">
            {isFirstPage && (
              <div className="m-wizard-form__form-header">
                {title && <h1>{title}</h1>}
                {subtitle && <h2>{subtitle}</h2>}
                {description && <p>{description}</p>}
              </div>
            )}
            {Page}
          </div>
        </>
      )}
      {displayOutro && <Outro />}
    </div>
  );
};

export default WizardForm;
