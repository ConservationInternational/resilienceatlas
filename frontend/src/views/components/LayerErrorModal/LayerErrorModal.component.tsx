import { useState, useCallback } from 'react';
import ReactModal from 'react-modal';
import { T } from '@transifex/react';
import cx from 'classnames';

import styles from './LayerErrorModal.module.scss';

export type LayerError = {
  layerId: string | number;
  layerName: string;
  errorType?: 'layer' | 'bounds';
  errorDescription?: string;
  provider?: string;
  url?: string | null;
  error: Error & {
    response?: {
      status?: number;
      statusText?: string;
      data?: unknown;
    };
    config?: { url?: string };
  };
  timestamp: number;
};

type LayerErrorModalProps = {
  errors: LayerError[];
  onClose: () => void;
  onDismissError: (layerId: string | number) => void;
};

const LayerErrorModal: React.FC<LayerErrorModalProps> = ({ errors, onClose, onDismissError }) => {
  const [expandedErrors, setExpandedErrors] = useState<Set<string | number>>(new Set());

  const toggleExpanded = useCallback((layerId: string | number) => {
    setExpandedErrors((prev) => {
      const next = new Set(prev);
      if (next.has(layerId)) {
        next.delete(layerId);
      } else {
        next.add(layerId);
      }
      return next;
    });
  }, []);

  const handleDismiss = useCallback(
    (layerId: string | number) => {
      onDismissError(layerId);
    },
    [onDismissError],
  );

  const getErrorSummary = (err: LayerError): string => {
    // Provide a user-friendly summary based on error type and status
    const status = err.error.response?.status;

    if (status === 404) {
      return 'The layer data could not be found. It may have been removed or the URL may be incorrect.';
    }
    if (status === 400) {
      return 'The request for layer data was invalid. The layer configuration may be incorrect.';
    }
    if (status === 403) {
      return 'Access to this layer is not permitted. You may need to log in or request access.';
    }
    if (status === 500 || status === 502 || status === 503) {
      return 'The server encountered an error. Please try again later.';
    }
    if (err.errorDescription) {
      return err.errorDescription;
    }
    return 'An unexpected error occurred while loading this layer.';
  };

  const getErrorDetails = (err: LayerError) => {
    const details: string[] = [];
    const { error } = err;

    // What failed
    if (err.errorType) {
      const typeLabel = err.errorType === 'bounds' ? 'Layer boundaries' : 'Layer data';
      details.push(`Failed to load: ${typeLabel}`);
    }

    // Provider
    if (err.provider) {
      details.push(`Data provider: ${err.provider}`);
    }

    // Status code
    if (error.response?.status) {
      details.push(`HTTP Status: ${error.response.status} ${error.response.statusText || ''}`);
    }

    // URL (show full URL)
    const url = err.url || error.config?.url;
    if (url) {
      details.push(`URL: ${url}`);
    }

    // Error message
    if (error.message) {
      details.push(`Error: ${error.message}`);
    }

    // Error type
    if (error.name && error.name !== 'Error') {
      details.push(`Error type: ${error.name}`);
    }

    // API response data (if JSON was returned)
    if (error.response?.data) {
      const data = error.response.data;
      if (typeof data === 'object' && data !== null) {
        // Extract common error fields from API responses
        const apiData = data as Record<string, unknown>;
        if (apiData.error) {
          details.push(`API Error: ${String(apiData.error)}`);
        }
        if (apiData.message) {
          details.push(`API Message: ${String(apiData.message)}`);
        }
        if (apiData.errors && Array.isArray(apiData.errors)) {
          details.push(`API Errors: ${apiData.errors.join(', ')}`);
        }
        if (apiData.detail) {
          details.push(`Detail: ${String(apiData.detail)}`);
        }
        if (apiData.hint) {
          details.push(`Hint: ${String(apiData.hint)}`);
        }
        // For any other data, show as JSON if it has content we haven't already displayed
        const knownKeys = ['error', 'message', 'errors', 'detail', 'hint'];
        const otherKeys = Object.keys(apiData).filter((k) => !knownKeys.includes(k));
        if (otherKeys.length > 0) {
          const otherData = Object.fromEntries(otherKeys.map((k) => [k, apiData[k]]));
          try {
            const jsonStr = JSON.stringify(otherData, null, 2);
            if (jsonStr !== '{}') {
              details.push(`Response data: ${jsonStr}`);
            }
          } catch {
            // Ignore JSON stringify errors
          }
        }
      } else if (typeof data === 'string' && data.length > 0) {
        details.push(`Response: ${data}`);
      }
    }

    return details;
  };

  if (errors.length === 0) {
    return null;
  }

  return (
    <ReactModal
      isOpen={errors.length > 0}
      parentSelector={() => document.querySelector('#root')}
      overlayClassName={styles.overlay}
      className={styles.modal}
      onRequestClose={onClose}
    >
      <div className={styles.wrapper}>
        <button className={styles.closeButton} onClick={onClose} aria-label="Close">
          &times;
        </button>

        <div className={styles.container}>
          <div className={styles.header}>
            <div className={styles.iconWrapper}>
              <svg
                className={styles.icon}
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
              >
                <circle cx="12" cy="12" r="10" />
                <line x1="12" y1="8" x2="12" y2="12" />
                <line x1="12" y1="16" x2="12.01" y2="16" />
              </svg>
            </div>
            <h2 className={styles.title}>
              <T
                _str="{count, plural, one {Layer failed to load} other {# layers failed to load}}"
                count={errors.length}
              />
            </h2>
          </div>

          <p className={styles.description}>
            <T _str="Some map layers could not be loaded. This may be due to a temporary issue or the data may not be available." />
          </p>

          <div className={styles.errorList}>
            {errors.map((err) => {
              const isExpanded = expandedErrors.has(err.layerId);
              const summary = getErrorSummary(err);
              const details = getErrorDetails(err);

              return (
                <div key={err.layerId} className={styles.errorItem}>
                  <div className={styles.errorHeader}>
                    <span className={styles.layerName}>{err.layerName}</span>
                    <button
                      className={styles.dismissButton}
                      onClick={() => handleDismiss(err.layerId)}
                      aria-label="Dismiss error"
                    >
                      <T _str="Dismiss" />
                    </button>
                  </div>

                  <p className={styles.errorSummary}>{summary}</p>

                  <button
                    className={cx(styles.expandButton, { [styles.expanded]: isExpanded })}
                    onClick={() => toggleExpanded(err.layerId)}
                    aria-expanded={isExpanded}
                  >
                    <svg
                      className={styles.chevron}
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="currentColor"
                      strokeWidth="2"
                    >
                      <polyline points="6 9 12 15 18 9" />
                    </svg>
                    <T _str="More information" />
                  </button>

                  {isExpanded && (
                    <div className={styles.errorDetails}>
                      {details.length > 0 ? (
                        <ul>
                          {details.map((detail, index) => (
                            <li key={index}>{detail}</li>
                          ))}
                        </ul>
                      ) : (
                        <p>
                          <T _str="No additional details available." />
                        </p>
                      )}
                    </div>
                  )}
                </div>
              );
            })}
          </div>

          <div className={styles.actions}>
            <button className={styles.primaryButton} onClick={onClose}>
              <T _str="Continue" />
            </button>
          </div>
        </div>
      </div>
    </ReactModal>
  );
};

export default LayerErrorModal;
