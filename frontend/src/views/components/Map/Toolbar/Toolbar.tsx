import React, { useCallback, useState } from 'react';
import cx from 'classnames';
import { Popover, PopoverButton, PopoverPanel } from '@headlessui/react';
import { useSelector } from 'react-redux';

import type { RootState } from 'state/types';
import ShareModal from 'views/components/ShareModal';
import SearchArea from './SearchArea';
import BasemapButton from './BasemapButton';
import BoundariesButton from './BoundariesButton';
import LabelsButton from './LabelsButton';
import { useMapSettingsSync } from './useMapSettingsSync';

const Toolbar: React.FC = () => {
  useMapSettingsSync();
  const [isModalOpen, setIsModalOpen] = useState(false);
  const handleModalToggle = useCallback(() => setIsModalOpen(!isModalOpen), [isModalOpen]);
  const hasSearch = useSelector((state: RootState) => state.site.has_search);

  return (
    <div className="m-toolbar">
      <ul>
        {hasSearch !== false && (
          <li className="m-toolbar__item">
            <Popover>
              {({ open, close }) => (
                <div className={cx('m-toolbar__item--search', { 'is-open': open })}>
                  <PopoverButton className="m-toolbar-item--button">
                    <svg className="icon">
                      <use xmlnsXlink="http://www.w3.org/1999/xlink" xlinkHref="#icon-search" />
                    </svg>
                  </PopoverButton>
                  <PopoverPanel className="m-toolbar-item--panel">
                    <SearchArea onAfterChange={close} />
                  </PopoverPanel>
                </div>
              )}
            </Popover>
          </li>
        )}
        <li className="m-toolbar__item m-toolbar__item--gap-after">
          <button type="button" className="btn-share" onClick={handleModalToggle}>
            <svg className="icon">
              <use xmlnsXlink="http://www.w3.org/1999/xlink" xlinkHref="#icon-share" />
            </svg>
          </button>
        </li>
        <li className="m-toolbar__item">
          <BasemapButton />
        </li>
        <li className="m-toolbar__item">
          <BoundariesButton />
        </li>
        <li className="m-toolbar__item">
          <LabelsButton />
        </li>
      </ul>
      <ShareModal isOpen={isModalOpen} setIsOpen={setIsModalOpen} />
    </div>
  );
};

export default Toolbar;
