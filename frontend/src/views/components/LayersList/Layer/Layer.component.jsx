import React, { useCallback, useContext } from 'react';
import cx from 'classnames';
import { event } from 'utilities/ga';
import { T } from '@transifex/react';

import InfoWindow from 'views/components/InfoWindow';
import LoginRequiredWindow from 'views/components/LoginRequiredWindow';
import { LayerManagerContext } from 'views/contexts/layerManagerCtx';
import { useToggle, useInput, useUpdaterInput, useDebounce } from 'utilities';
import DownloadWindow from '../../DownloadWindow/DownloadWindow.component';
import { subdomain } from 'utilities/getSubdomain';

const validateOpacity = (value) => {
  if (Number.isNaN(value)) return 1;
  if (value > 1) return 1;
  if (value < 0) return 0;
  return value;
};

const Layer = (props) => {
  const {
    toggle,
    setOpacity,
    id,
    name,
    isActive,
    opacity_text,
    info,
    download,
    download_url,
    dashboard_order,
    withDashboardOrder,
    type,
    slug,
    user,
    subcategoryName,
    groupName,
    categoryName,
    subgroupName,
  } = props;
  const layerManagerRef = useContext(LayerManagerContext);
  const [isOpen, toggleOpen] = useToggle(false);
  const slider = useInput('opacity_slider', opacity_text);
  const opacityInput = useUpdaterInput(id, opacity_text, (v) => {
    setOpacity(id, validateOpacity(v / 100));
  });
  const toggleLayer = useCallback(() => {
    toggle(id);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id]);

  useDebounce(
    () => {
      if (slider.value !== opacity_text) {
        setOpacity(id, validateOpacity(slider.value / 100));
      }
    },
    300,
    [slider.value],
  );

  var readyToDownload = user.auth_token || subdomain;

  const fitMapToLayer = useCallback(() => {
    layerManagerRef.current.fitMapToLayer(id);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const sendAnalyticsEvent = () =>
    event({
      action: 'select_item',
      params: {
        items: [
          {
            item_id: id,
            item_name: name,
            item_category: groupName,
            item_category2: categoryName,
            item_category3: subcategoryName,
            item_category4: subgroupName,
          },
        ],
        item_list_name: 'Map Layers',
        item_list_id: 'map_layers',
      },
    });

  return (
    <li
      className={cx('layer', {
        'is-modified': opacity_text !== 100,
        'is-open': isOpen,
        [dashboard_order]: withDashboardOrder && !!dashboard_order,
      })}
    >
      <div className="panel-item-switch m-form-input--switch">
        <input
          type="checkbox"
          data-name={name}
          className="panel-input-switch"
          id={`layer_${id}`}
          checked={isActive}
          onChange={() => {
            toggleLayer();
            if (!isActive) {
              sendAnalyticsEvent();
            }
          }}
        />
        <label htmlFor={`layer_${id}`} />
      </div>

      <div className="panel-item-title">{name}</div>

      <button
        type="button"
        className="btn-locate icon-container panel-trasparecy-switcher"
        data-id={id}
        onClick={fitMapToLayer}
        disabled={!isActive}
      >
        <svg className="icon icon-zoom-pan">
          <use xlinkHref="#icon-zoom-pan" />
        </svg>
      </button>

      <button
        type="button"
        className="btn-opacity icon-container panel-trasparecy-switcher"
        onClick={toggleOpen}
      >
        <svg className="icon icon-settings">
          <use xlinkHref="#icon-settings" />
        </svg>
      </button>

      {!!info && (
        <button
          type="button"
          className="btn-info icon-container panel-trasparecy-switcher"
          data-info={info}
          data-name={name}
          onClick={() => {
            InfoWindow.show(name, JSON.parse(info));
          }}
        >
          <svg className="icon icon-info">
            <use xlinkHref="#icon-info" />
          </svg>
        </button>
      )}

      {!!download && type !== 'gee' && !/forest-carbon-stock/.test(slug) && (
        <button
          type="button"
          data-name={name}
          className="btn-download icon-container panel-trasparecy-switcher"
          // eslint-disable-next-line react/no-unknown-property
          attr="download"
          title={
            readyToDownload ? (
              <T _str="Layers" />
            ) : (
              <T _str="Please login to enable download feature." />
            )
          }
          onClick={() => {
            if (readyToDownload) {
              DownloadWindow.show(download_url, `${name} - ${(<T _str="Layer" />)}`, categoryName);
            } else {
              LoginRequiredWindow.show();
            }
          }}
        >
          {/* eslint-disable-next-line */}
          <svg className="icon icon-downloads" opacitylevel={opacity_text}>
            <use xlinkHref="#icon-downloads" />
          </svg>
        </button>
      )}
      <div className="panel-item-slider">
        <div className="m-form-input--slider">
          <div className="slider-wrapper">
            <input
              data-id={id}
              id="fader"
              className="opacity-range"
              {...slider}
              type="range"
              min="0"
              max="100"
              step="1"
            />
            <span className="opacity" style={{ width: `${slider.value}%` }} />
          </div>
          <div className="value">
            <input
              type="number"
              className="opacity-teller"
              // eslint-disable-next-line react/no-unknown-property
              layer={id}
              {...opacityInput}
              min="0"
              max="100"
              step="1"
            />
            <span>%</span>
          </div>
        </div>
      </div>
    </li>
  );
};

export default Layer;
