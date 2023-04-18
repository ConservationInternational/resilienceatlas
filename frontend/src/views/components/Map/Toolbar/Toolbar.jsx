import React, { useCallback, useState } from 'react';
import ShareModal from 'views/components/ShareModal';
import SearchArea from './SearchArea';

const Toolbar = () => {
  const [isModalOpen, setIsModalOpen] = useState(false);
  const handleModalToggle = useCallback(() => setIsModalOpen(!isModalOpen), [isModalOpen]);

  return (
    <div className="m-toolbar">
      <ul>
        <li className="m-toolbar__item search">
          <svg className="icon">
            <use xmlnsXlink="http://www.w3.org/1999/xlink" xlinkHref="#icon-search" />
          </svg>
          <SearchArea />
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
