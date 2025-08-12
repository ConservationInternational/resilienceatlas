import React, { useState, useEffect } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { reduxForm, Field } from 'redux-form';
import { T } from '@transifex/react';

import {
  authenticateWithSiteScope,
  hideAuthModal,
  clearAuthError,
  getSiteScopeAuthError,
  isSiteScopeAuthLoading,
  shouldShowSiteScopeAuthModal,
  getCurrentSiteScope,
} from 'state/modules/site_scope_auth';

import styles from './site-scope-auth-modal.module.scss';

const SiteScopeAuthModal = ({ handleSubmit }) => {
  const dispatch = useDispatch();
  const error = useSelector(getSiteScopeAuthError);
  const loading = useSelector(isSiteScopeAuthLoading);
  const showModal = useSelector(shouldShowSiteScopeAuthModal);
  const currentSiteScope = useSelector(getCurrentSiteScope);

  const [localError, setLocalError] = useState(null);
  const [hasMounted, setHasMounted] = useState(false);

  useEffect(() => {
    setHasMounted(true);
  }, []);

  const onSubmit = async (values) => {
    setLocalError(null);

    if (!values.username || !values.password) {
      setLocalError('Please enter both username and password');
      return;
    }

    try {
      await dispatch(authenticateWithSiteScope(currentSiteScope, values.username, values.password));
      // Modal will be closed automatically by the action
    } catch (err) {
      // Error is handled by the reducer
      setLocalError(err.message);
    }
  };

  const handleClose = () => {
    dispatch(hideAuthModal());
    dispatch(clearAuthError());
    setLocalError(null);
  };

  // Prevent hydration mismatches by not rendering until client-side mount
  if (!hasMounted || !showModal) return null;

  const displayError = localError || error;

  return (
    <div className={styles['site-scope-auth-modal-overlay']}>
      <div className={styles['site-scope-auth-modal']}>
        <div className={styles['site-scope-auth-modal__header']}>
          <h2>
            <T _str="Authentication Required" />
          </h2>
          <button
            type="button"
            className={styles['site-scope-auth-modal__close']}
            onClick={handleClose}
            disabled={loading}
          >
            ×
          </button>
        </div>

        <div className={styles['site-scope-auth-modal__content']}>
          <p>
            <T _str="This site requires authentication to access its content. Please enter your credentials." />
          </p>

          <form onSubmit={handleSubmit(onSubmit)} className={styles['site-scope-auth-form']}>
            <div className={styles['form-group']}>
              <label htmlFor="username">
                <T _str="Username" />
              </label>
              <Field
                name="username"
                component="input"
                type="text"
                className={styles['form-control']}
                disabled={loading}
                required
              />
            </div>

            <div className={styles['form-group']}>
              <label htmlFor="password">
                <T _str="Password" />
              </label>
              <Field
                name="password"
                component="input"
                type="password"
                className={styles['form-control']}
                disabled={loading}
                required
              />
            </div>

            {displayError && (
              <div className={`${styles['alert']} ${styles['alert-error']}`}>{displayError}</div>
            )}

            <div className={styles['form-actions']}>
              <button
                type="button"
                className={`${styles['btn']} ${styles['btn-secondary']}`}
                onClick={handleClose}
                disabled={loading}
              >
                <T _str="Cancel" />
              </button>
              <button
                type="submit"
                className={`${styles['btn']} ${styles['btn-primary']}`}
                disabled={loading}
              >
                {loading ? <T _str="Authenticating..." /> : <T _str="Login" />}
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  );
};

export default reduxForm({
  form: 'siteScopeAuth',
  destroyOnUnmount: true,
})(SiteScopeAuthModal);
