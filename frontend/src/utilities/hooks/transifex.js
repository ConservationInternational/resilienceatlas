import { useEffect } from 'react';
import { connect } from 'react-redux';
import { setTranslations } from 'state/modules/translations';

export const useSetServerSideTranslations = ({ setTranslations, translations }) => {
  useEffect(() => {
    if (setTranslations) {
      // Store the translations in redux for child components
      setTranslations(translations);
    }
  }, [setTranslations, translations]);
};

export const withTranslations = (Component) => {
  const mapDispatchToProps = {
    setTranslations,
  };
  return connect(null, mapDispatchToProps)(Component);
};
