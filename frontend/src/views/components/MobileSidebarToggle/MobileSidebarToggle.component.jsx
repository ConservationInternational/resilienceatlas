import React from 'react';
import { connect } from 'react-redux';
import cx from 'classnames';
import { toggleSidebar } from 'state/modules/ui';
import styles from './MobileSidebarToggle.module.scss';

/**
 * Mobile-only toggle button for the sidebar.
 * This component lives OUTSIDE the sidebar container so it remains
 * visible even when the sidebar is collapsed (transformed off-screen).
 */
const MobileSidebarToggle = ({ isSidebarOpen, toggleSidebar }) => {
  return (
    <button
      className={cx(styles.mobileToggle, {
        [styles.isCollapsed]: !isSidebarOpen,
      })}
      type="button"
      onClick={toggleSidebar}
      aria-label={isSidebarOpen ? 'Close sidebar' : 'Open sidebar'}
    >
      <span className={styles.arrow} />
    </button>
  );
};

export default connect(
  (state) => ({
    isSidebarOpen: state.ui.sidebar,
  }),
  { toggleSidebar },
)(MobileSidebarToggle);
