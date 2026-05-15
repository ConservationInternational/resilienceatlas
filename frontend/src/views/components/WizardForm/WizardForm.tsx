import type { ReactNode } from 'react';
import React, { Children, useState } from 'react';
import { useRouter } from 'next/router';
import cx from 'classnames';
import { useForm, FormProvider } from 'react-hook-form';
import { yupResolver } from '@hookform/resolvers/yup';
import type { TypedT } from 'types/transifex';
import { T } from '@transifex/react';
import type { ObjectSchema } from 'yup';

import Pagination from './Pagination/Pagination.component';

interface WizardFormProps {
  title?: TypedT;
  subtitle?: TypedT;
  description?: TypedT;
  submitButton?: string;
  onSubmit: (values: Record<string, unknown>) => void;
  children: unknown | unknown[];
  formSubmitted: boolean;
  outroComponent: unknown;
  backBtnPath?: string;
  backBtnText?: string;
  errorMessage?: string;
  validationSchemas?: ObjectSchema<Record<string, unknown>>[];
}

const WizardForm: React.FC<WizardFormProps> = (props) => {
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
    validationSchemas = [],
  } = props;

  // Initialized to the current page number, not array indexes
  const [currentPage, setCurrentPage] = useState(1);
  const router = useRouter();

  const pagesComponents = Children.toArray(children as ReactNode[]) as React.ReactElement[];
  const numPages = pagesComponents.length;
  const isFirstPage = currentPage === 1;
  const isLastPage = currentPage === numPages;

  // Get the current page's validation schema (if any)
  const currentSchema = validationSchemas[currentPage - 1];

  const methods = useForm({
    resolver: currentSchema ? yupResolver(currentSchema) : undefined,
    mode: 'onBlur',
    shouldUnregister: false,
  });

  const { handleSubmit: rhfHandleSubmit, getValues, trigger } = methods;

  const handleBackButtonClick = () => {
    router.push(backBtnPath as string);
  };

  const handlePreviousPageClick = () => {
    setCurrentPage(currentPage - 1);
  };

  const handleNextPageClick = async () => {
    // Validate current page before moving to next
    const isValid = await trigger();
    if (isValid) {
      setCurrentPage(currentPage + 1);
    }
  };

  const handleFormSubmit = async (values: Record<string, unknown>) => {
    if (!isLastPage) {
      await handleNextPageClick();
    } else {
      onSubmit(values);
    }
  };

  const currentPageComponent = pagesComponents[currentPage - 1];

  const Page = React.cloneElement(currentPageComponent, {
    showTitle: !isFirstPage,
    onPrevious: handlePreviousPageClick,
    submitButton,
    isFirstPage,
    isLastPage,
    errorMessage,
    formValues: getValues(),
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
        <FormProvider {...methods}>
          <form onSubmit={rhfHandleSubmit(handleFormSubmit)}>
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
          </form>
        </FormProvider>
      )}
      {displayOutro && <Outro />}
    </div>
  );
};

export default WizardForm;
