import React from 'react';
import ShareModal from '../../ShareModal/ShareModal.component';
import SearchArea from './SearchArea';

const Toolbar = () => (
  <div className="m-toolbar">
    <ul>
      <li className="m-toolbar__item search">
        <svg className="icon">
          <use xmlnsXlink="http://www.w3.org/1999/xlink" xlinkHref="#icon-search" />
        </svg>
        <SearchArea />
      </li>
      <li className="m-toolbar__item">
        <button type="button" className="btn-share" onClick={ShareModal.show}>
          <svg className="icon">
            <use xmlnsXlink="http://www.w3.org/1999/xlink" xlinkHref="#icon-share" />
          </svg>
        </button>
      </li>
    </ul>
  </div>
);

export default Toolbar;
