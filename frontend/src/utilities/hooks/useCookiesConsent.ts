import { useCallback, useEffect, useState } from 'react';

import { useSyncedState } from 'utilities/hooks/useSyncedState';

interface CookiesConsent {
  /** Whether the user consented to the use of cookies */
  allowCookies: boolean | null;
  /** The date at which the user consented to the use of or refused the cookies */
  consentDate?: number | null;
  /**
   * Update the consent status of the cookies
   */
  updateConsent: (allowCookies: boolean, consentDate: number) => void;
}

/** Key of the allowCookie setting in the `localStorage` */
export const ALLOW_COOKIE_KEY = 'allowCookies';
/** Key of the cookiesConsentDate setting in the `localStorage` */
export const CONSENT_DATE_KEY = 'cookiesConsentDate';

/**
 * Return the privacy settings stored in the `localStorage`
 */
export const getSettingsFromLocalStorage = () => {
  try {
    const storedAllowCookies = localStorage.getItem(ALLOW_COOKIE_KEY);
    const storedConsentDate = localStorage.getItem(CONSENT_DATE_KEY);

    const allowCookies = storedAllowCookies === 'true';
    const consentDate =
      typeof storedConsentDate === 'string' &&
      storedConsentDate.length > 0 &&
      !Number.isNaN(+storedConsentDate)
        ? +storedConsentDate
        : null;

    if (consentDate !== null) {
      return { allowCookies, consentDate };
    }
  } catch (e) {
    console.error('Unable to access the localStorage.');
  }

  return null;
};

/**
 * Save the privacy settings in the `localStorage`
 * @param allowCookies Whether the user consents to the use of cookies
 * @param consentDate Dates at which the user consented or refused the use of cookies
 * @returns True if the settings have been saved successfully
 */
export const saveSettingsInLocalStorage = (allowCookies: boolean, consentDate: number) => {
  try {
    localStorage.setItem(ALLOW_COOKIE_KEY, `${allowCookies}`);
    localStorage.setItem(CONSENT_DATE_KEY, `${consentDate}`);
    return true;
  } catch (e) {
    console.error('Unable to access the localStorage');
  }

  return false;
};

export const useCookiesConsent = (): CookiesConsent => {
  const [allowCookies, setAllowCookies] = useState<boolean>(null);
  const [consentDate, setConsentDate] = useState<number>(null);

  /** Callback executed when the synced state has received an update */
  const onUpdateSyncedState = useCallback(({ allowCookies, consentDate }) => {
    setAllowCookies(allowCookies);
    setConsentDate(consentDate);

    if (allowCookies !== null && consentDate !== null) {
      saveSettingsInLocalStorage(allowCookies, consentDate);
    }
  }, []);

  // We synchronise the state of all the components that rely on `useCookiesConsent` so that they
  // all have the most updated information about the consent
  const updateSyncedState = useSyncedState(
    {
      allowCookies: null,
      consentDate: null,
    },
    onUpdateSyncedState,
  );

  /** Callback executed when the user updates their consent */
  const onUpdateConsent: CookiesConsent['updateConsent'] = useCallback(
    (allowCookies, consentDate) => {
      updateSyncedState({ allowCookies, consentDate });
    },
    [updateSyncedState],
  );

  // On mount, we check if the user has already consented to the use of cookies
  useEffect(() => {
    const settings = getSettingsFromLocalStorage();
    if (!!settings) {
      updateSyncedState(settings);
    }
  }, [updateSyncedState]);

  return {
    allowCookies,
    consentDate,
    updateConsent: onUpdateConsent,
  };
};
