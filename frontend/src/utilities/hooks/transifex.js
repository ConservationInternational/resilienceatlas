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
  const ConnectedComponent = connect(null, mapDispatchToProps)(Component);

  // Preserve the Layout property for Next.js page layouts
  // This is critical for the layout pattern used in _app.tsx
  if (Component.Layout) {
    ConnectedComponent.Layout = Component.Layout;
  }

  return ConnectedComponent;
};
