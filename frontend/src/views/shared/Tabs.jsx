import React from 'react';
import PropTypes from 'prop-types';
import cx from 'classnames';
import * as CustomTypes from '@utilities/propTypes';

export const Pane = ({ children, className, name, activeTab, ...props }) => (
  <div className={cx(className, { active: activeTab === name })} {...props}>
    {children}
  </div>
);

Pane.propTypes = {
  children: PropTypes.node,
  className: PropTypes.string,
  name: PropTypes.string.isRequired,
  activeTab: PropTypes.string,
};

Pane.defaultProps = {
  children: null,
  className: '',
  activeTab: '',
};

const Tabs = ({
  children,
  menuClassName,
  contentClassName,
  renderTabTitle,
  activeTab,
  renderActiveOnly,
  onTabSwitch,
  hideDisabledTitles,
  defaultTab,
  ...props
}) => (
  <>
    {!!renderTabTitle && (
      <ul className={menuClassName} role="tablist" data-tab>
        {React.Children.map(children, Tab => {
          if (!Tab) return null;
          const { name, title, disabled } = Tab.props;
          if (hideDisabledTitles && disabled) return null;

          return renderTabTitle({
            name,
            active: activeTab === name,
            onTabSwitch: onTabSwitch.bind(null, { tab: name }),
            title,
            disabled,
          });
        })}
      </ul>
    )}

    <div {...props} className={contentClassName}>
      {React.Children.map(children, Tab => {
        if (!Tab) return null;
        const key = Tab.props.name;
        const isActive = key === activeTab;

        if (!renderActiveOnly || isActive) {
          if (hideDisabledTitles && Tab.props.disabled) {
            onTabSwitch({ tab: defaultTab });
            return null;
          }
          return React.cloneElement(Tab, { key, activeTab });
        }

        return null;
      })}
    </div>
  </>
);

Tabs.propTypes = {
  activeTab: PropTypes.string.isRequired,
  defaultTab: PropTypes.string,
  renderActiveOnly: PropTypes.bool,
  hideDisabledTitles: PropTypes.bool,
  children: CustomTypes.componentType(Pane).isRequired,
  onTabSwitch: PropTypes.func,
  menuClassName: PropTypes.string,
  contentClassName: PropTypes.string,
  renderTabTitle: PropTypes.func,
};

Tabs.defaultProps = {
  // children: null,
  renderActiveOnly: false,
  hideDisabledTitles: false,
  onTabSwitch: () => {},
  renderTabTitle: null,
  menuClassName: '',
  contentClassName: '',
  defaultTab: '',
};

Tabs.Pane = Pane;

export default Tabs;
