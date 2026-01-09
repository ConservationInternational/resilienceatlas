import type { ReactNode } from 'react';
import React, { Children, useState } from 'react';
import { useRouter } from 'next/router';
import cx from 'classnames';
import type { TypedT } from 'types/transifex';
import { T } from '@transifex/react';

import Pagination from './Pagination/Pagination.component';

const WizardForm: React.FC<{
  title?: TypedT;
  subtitle?: TypedT;
  description?: TypedT;
  submitButton?: string;
  onSubmit: (values) => void;
  children: unknown | unknown[];
  formSubmitted: boolean;
  outroComponent: unknown;
  backBtnPath?: string;
  backBtnText?: string;
  errorMessage?: string;
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
    backBtnPath,
    backBtnText,
    errorMessage,
  } = props;
  // Initialized to the current page number, not array indexes
  const [currentPage, setCurrentPage] = useState(1);

  const router = useRouter();

  const handleBackButtonClick = () => {
    router.push(backBtnPath);
  };

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
    errorMessage,
  } as React.Attributes & Record<string, unknown>);

  const Outro = outroComponent as React.ElementType;
  const displayOutro = formSubmitted && outroComponent;
  const displayPage = !displayOutro;

  return (
    <div
      className={cx('m-wizard-form', {
        'm-wizard-form--background-image': formSubmitted,
      })}
    >
      {backBtnPath && (
        <div className="m-wizard-form__header">
          <button
            type="button"
            className="m-wizard-form__button m-wizard-form__button--previous"
            onClick={handleBackButtonClick}
          >
            {backBtnText || <T _str="Go back" />}
          </button>
        </div>
      )}
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
