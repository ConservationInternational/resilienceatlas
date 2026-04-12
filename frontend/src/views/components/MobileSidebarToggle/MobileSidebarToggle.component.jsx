import React from 'react';
import { connect } from 'react-redux';
import cx from 'classnames';
import { toggleSidebar, toggleAnalysis } from 'state/modules/ui';
import styles from './MobileSidebarToggle.module.scss';

/**
 * Mobile-only toggle button for the sidebar.
 * This component lives OUTSIDE the sidebar container so it remains
 * visible even when the sidebar is collapsed (transformed off-screen).
 *
 * When the analysis panel is open, this button closes the analysis panel
 * instead of collapsing the sidebar, so users can return to the layers tab.
 */
const MobileSidebarToggle = ({
  isSidebarOpen,
  isAnalysisPanelOpen,
  toggleSidebar,
  toggleAnalysis,
}) => {
  const handleClick = () => {
    if (isAnalysisPanelOpen) {
      toggleAnalysis();
    } else {
      toggleSidebar();
    }
  };

  return (
    <button
      className={cx(styles.mobileToggle, {
        [styles.isCollapsed]: !isSidebarOpen && !isAnalysisPanelOpen,
      })}
      type="button"
      onClick={handleClick}
      aria-label={
        isAnalysisPanelOpen
          ? 'Close analysis panel'
          : isSidebarOpen
            ? 'Close sidebar'
            : 'Open sidebar'
      }
    >
      <span className={styles.arrow} />
    </button>
  );
};

export default connect(
  (state) => ({
    isSidebarOpen: state.ui.sidebar,
    isAnalysisPanelOpen: state.ui.analysisPanel,
  }),
  { toggleSidebar, toggleAnalysis },
)(MobileSidebarToggle);
