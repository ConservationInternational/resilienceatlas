import React, { useCallback, useEffect, useState } from 'react';
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
import { subdomain } from 'utilities/getSubdomain';

// SSR translated strings
export const TABS = {
  LAYERS: 'layers',
  MODELS: 'models',
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
  translations,
}) => {
  const router = useRouter();
  const { setParam } = useRouterParams();
  const [hasMounted, setHasMounted] = useState(false);

  useEffect(() => {
    setHasMounted(true);
  }, []);

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

  const handleFeedbackBtnClick = () => {
    const goBackString = translations['Go back to map'];
    router.push(
      `feedback/?returnPath=${encodeURIComponent(router.asPath)}&returnText=${encodeURIComponent(
        goBackString,
      )}`,
      'feedback',
    );
  };

  // Close sidebar when clicking backdrop on mobile
  const handleBackdropClick = useCallback(
    (e) => {
      // Mobile breakpoint constant matching SCSS $breakpoint-mobile
      const MOBILE_BREAKPOINT = 767;

      // Only handle backdrop clicks on mobile
      if (window.innerWidth <= MOBILE_BREAKPOINT && opened) {
        // Check if click is on the backdrop (outside the sidebar content)
        if (e.target.classList.contains('l-sidebar--fullscreen')) {
          toggleOpen();
        }
      }
    },
    [opened, toggleOpen],
  );

  const displayFeedbackButton = !subdomain;

  return (
    <div
      className={cx('l-sidebar--fullscreen', {
        'is-collapsed': !opened,
        analyzing: analysisOpened,
      })}
      onClick={handleBackdropClick}
    >
      <div className="l-sidebar-content" onClick={(e) => e.stopPropagation()}>
        {site?.has_analysis && <AnalysisPanel toggle={toggleAnalysis} />}

        <div className="m-sidebar" id="sidebarView">
          <Tabs
            activeTab={tab}
            defaultTab={TABS.LAYERS}
            onTabSwitch={switchTab}
            contentClassName="tabs-content content"
            menuClassName="tabs tabs-secondary-content"
            renderTabTitle={({ name, title, active, onTabSwitch }) => (
              <li className={cx('tab-title', { active })}>
                <LinkButton data-section={translations && translations[name]} onClick={onTabSwitch}>
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

            {site?.predictive_model && (
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
              resilience_atlas={
                <p className="site-title">
                  <a
                    href="http://www.resilienceatlas.org/"
                    target="_blank"
                    rel="noopener noreferrer"
                    title={<T _str="Resilience Atlas" />}
                  >
                    <T _str="Resilience Atlas" />
                  </a>
                </p>
              }
              by={
                <p className="site-title-by">
                  <T _str="by" _comment="{resilience_atlas} {by} {conservation_international}" />
                </p>
              }
              conservation_international={
                <a
                  className="brand-area"
                  href="http://www.conservation.org/"
                  target="_blank"
                  rel="noopener noreferrer"
                  title={<T _str="Conservation International" />}
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
          aria-label={translations && translations['Toggle sidebar']}
        />
        {hasMounted && site?.has_analysis && (
          <button
            className="btn-analysis-panel-expand"
            type="button"
            onClick={toggleAnalysis}
            aria-label={translations && translations['Expand analysis panel']}
          >
            <T _str="Analysis" />
          </button>
        )}
        <LogoAttribution />
        {hasMounted && displayFeedbackButton && (
          <button className="btn-map-feedback" type="button" onClick={handleFeedbackBtnClick}>
            <T _str="Feedback" />
          </button>
        )}
      </div>
    </div>
  );
};

export default Sidebar;
