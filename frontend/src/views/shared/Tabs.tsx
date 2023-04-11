import React from 'react';
import cx from 'classnames';

type RenderTabTitleProps = {
  name: string;
  active: boolean;
  onTabSwitch: () => void;
  title: string;
  disabled: boolean;
};

type PaneProps = React.HTMLAttributes<HTMLDivElement> & {
  name: string;
  activeTab?: string;
};

type TabsProps = React.FC<
  React.HTMLAttributes<HTMLDivElement> & {
    activeTab: string;
    renderActiveOnly?: boolean;
    hideDisabledTitles?: boolean;
    onTabSwitch?: ({ tab }: { tab: string }) => void;
    renderTabTitle?: (props: RenderTabTitleProps) => React.ReactNode;
    menuClassName: string;
    contentClassName: string;
    defaultTab: string;
  }
> & {
  Pane: React.FC<PaneProps>;
};

type TabProps = React.ReactNode & {
  props: {
    title: string;
    disabled: boolean;
  };
};

export const Pane: React.FC<PaneProps> = ({ children, className, name, activeTab, ...props }) => (
  <div className={cx(className, { active: activeTab === name })} {...props}>
    {children}
  </div>
);

const Tabs: TabsProps = ({
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
        {React.Children.map(children, (Tab: TabProps) => {
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
      {React.Children.map(children, (Tab: TabProps) => {
        if (!Tab) return null;
        const key = Tab.props.name;
        const isActive = key === activeTab;

        if (!renderActiveOnly || isActive) {
          if (hideDisabledTitles && Tab.props.disabled) {
            onTabSwitch({ tab: defaultTab });
            return null;
          }
          return React.cloneElement(Tab as React.ReactElement, { key, activeTab });
        }

        return null;
      })}
    </div>
  </>
);

Tabs.Pane = Pane;

export default Tabs;
