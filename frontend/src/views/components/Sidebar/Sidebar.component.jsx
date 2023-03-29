import React, { useCallback, useEffect } from 'react';
import cx from 'classnames';
import { useRouter } from 'next/router';
import { T } from '@transifex/react';

import AnalysisPanel from 'views/components/AnalysisPanel';
import LayersList from 'views/components/LayersList';
import PredictiveModels from 'views/components/PredictiveModels';
import LogoAttribution from 'views/components/LogoAttribution';

import LinkButton from 'views/shared/LinkButton';
import Tabs from 'views/shared/Tabs';

import { useRouterParams } from 'utilities';

export const TABS = {
  LAYERS: <T _str="layers" />,
  MODELS: <T _str="models" />,
};

const Sidebar = ({
  // Actions
  toggleOpen,
  toggleAnalysis,
  setTab,
  // Data
  tab,
  opened,
  analysisOpened,
  site,
}) => {
  const router = useRouter();
  const { setParam } = useRouterParams();

  useEffect(() => {
    if (router.isReady && tab) {
      setParam('tab', tab);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [router.isReady, tab]);

  const switchTab = useCallback(
    ({ tab: newTab }) => {
      if (tab !== newTab) {
        setTab(newTab);
      }
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [tab],
  );

  return (
    <div
      className={cx('l-sidebar--fullscreen', {
        'is-collapsed': !opened,
        analyzing: analysisOpened,
      })}
    >
      <div className="l-sidebar-content">
        {site.has_analysis && <AnalysisPanel toggle={toggleAnalysis} />}

        <div className="m-sidebar" id="sidebarView">
          <Tabs
            activeTab={tab}
            defaultTab={TABS.LAYERS}
            onTabSwitch={switchTab}
            contentClassName="tabs-content content"
            menuClassName="tabs tabs-secondary-content"
            renderTabTitle={({ name, title, active, onTabSwitch }) => (
              <li className={cx('tab-title', { active })}>
                <LinkButton data-section={name} onClick={onTabSwitch}>
                  {title}
                </LinkButton>
              </li>
            )}
          >
            <Tabs.Pane
              id="layersListView"
              className="m-layers-list content"
              title={<T _str="Layers" />}
              name={TABS.LAYERS}
            >
              <LayersList />
            </Tabs.Pane>

            {site.predictive_model && (
              <Tabs.Pane
                id="modelContent"
                className="m-model-content content"
                title={<T _str="Predictive models" />}
                name={TABS.MODELS}
              >
                <PredictiveModels />
              </Tabs.Pane>
            )}
          </Tabs>

          <div className="sidebar-logo">
            <T
              _str="{resilience_atlas} {by} {conservation_international}"
              _resilience_atlas={
                <p className="site-title">
                  <a
                    href="http://www.resilienceatlas.org/"
                    target="_blank"
                    rel="noopener noreferrer"
                    title="Resilience Atlas"
                  >
                    <T _str="Resilience Atlas" />
                  </a>
                </p>
              }
              _by={
                <p className="site-title-by">
                  <T _str="by" _comment="{resilience_atlas} {by} {conservation_international}" />
                </p>
              }
              _conservation_international={
                <a
                  className="brand-area"
                  href="http://www.conservation.org/"
                  target="_blank"
                  rel="noopener noreferrer"
                  title="Conservation International"
                >
                  <T _str="Conservation International" />
                </a>
              }
            />
            <p className="site-copyright">
              © <T _str="2016 Conservation International" />
            </p>
          </div>
        </div>
        <button
          className="btn-sidebar-toggle"
          type="button"
          onClick={toggleOpen}
          aria-label={<T _str="Toggle sidebar" />}
        />
        {site.has_analysis && (
          <button
            className="btn-analysis-panel-expand"
            type="button"
            onClick={toggleAnalysis}
            aria-label={<T _str="Expand analysis panel" />}
          >
            <T _str="Analysis" />
          </button>
        )}
        <LogoAttribution />
      </div>
    </div>
  );
};

export default Sidebar;
