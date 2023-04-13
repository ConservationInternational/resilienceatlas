import React, { useCallback, useState } from 'react';
import cx from 'classnames';
import { Popover } from '@headlessui/react';

import ShareModal from 'views/components/ShareModal';
import SearchArea from './SearchArea';

const Toolbar: React.FC = () => {
  const [isModalOpen, setIsModalOpen] = useState(false);
  const handleModalToggle = useCallback(() => setIsModalOpen(!isModalOpen), [isModalOpen]);

  return (
    <div className="m-toolbar">
      <ul>
        <li className="m-toolbar__item">
          <Popover>
            {({ open, close }) => (
              <div className={cx('m-toolbar__item--search', { 'is-open': open })}>
                <Popover.Button className="m-toolbar-item--button">
                  <svg className="icon">
                    <use xmlnsXlink="http://www.w3.org/1999/xlink" xlinkHref="#icon-search" />
                  </svg>
                </Popover.Button>
                <Popover.Panel className="m-toolbar-item--panel">
                  <SearchArea onAfterChange={close} />
                </Popover.Panel>
              </div>
            )}
          </Popover>
        </li>
        <li className="m-toolbar__item">
          <button type="button" className="btn-share" onClick={handleModalToggle}>
            <svg className="icon">
              <use xmlnsXlink="http://www.w3.org/1999/xlink" xlinkHref="#icon-share" />
            </svg>
          </button>
        </li>
      </ul>
      <ShareModal isOpen={isModalOpen} setIsOpen={setIsModalOpen} />
    </div>
  );
};

export default Toolbar;
