import { useCallback, useState } from 'react';
import ReactModal from 'react-modal';
import cx from 'classnames';

import Tabs from 'views/shared/Tabs';
import LinkButton from 'views/shared/LinkButton';
import CopyToClipboard from 'views/shared/CopyToClipboard';

import { useRouter } from 'next/router';

type ShareModalProps = {
  isOpen: boolean;
  setIsOpen: (isOpen: boolean) => void;
};

const TABS: Record<string, string> = {
  LINK: 'share-link',
  EMBED: 'share-embed',
  OEMBED: 'share-oembed',
};

const ShareModal: React.FC<ShareModalProps> = ({ isOpen, setIsOpen }) => {
  const { asPath } = useRouter();
  const [tab, setTab] = useState(TABS.LINK);

  const origin = typeof window !== 'undefined' ? window.location.origin : '';
  const url = `${origin}${asPath}`;

  const switchTab = useCallback(
    (e: React.MouseEvent<HTMLButtonElement>) => {
      const newTab = e.currentTarget.dataset.tab;
      if (tab !== newTab) {
        setTab(newTab);
      }
    },
    [tab],
  );

  const handleClose = useCallback(() => setIsOpen(false), [setIsOpen]);

  return (
    <ReactModal
      isOpen={isOpen}
      parentSelector={() => document.querySelector('#root')}
      overlayClassName="modal-background"
      className="m-modal-window m-share"
      onRequestClose={handleClose} // allow to close modal with ESC key
    >
      <div className="modal-wrapper">
        <button className="btn-close-modal" onClick={handleClose}>
          &times;
        </button>
        <div className="modal-container is-loading-share">
          <div className="modal-content">
            <div className="share-nav">
              <h2>Share</h2>

              <ul className="tabs tabs-secondary-content">
                <li className={cx('tab-title', { active: tab === TABS.LINK })}>
                  <LinkButton data-tab={TABS.LINK} onClick={switchTab}>
                    Link
                  </LinkButton>
                </li>
                <li className={cx('tab-title', { active: tab === TABS.EMBED })}>
                  <LinkButton data-tab={TABS.EMBED} onClick={switchTab}>
                    Embed
                  </LinkButton>
                </li>
                <li className={cx('tab-title', { active: tab === TABS.OEMBED })}>
                  <LinkButton data-tab={TABS.OEMBED} onClick={switchTab}>
                    OEmbed
                  </LinkButton>
                </li>
              </ul>
            </div>

            <Tabs
              activeTab={tab}
              defaultTab={TABS.LINK}
              renderActiveOnly
              contentClassName="tabs-content content"
              menuClassName="tabs tabs-secondary-content"
            >
              <Tabs.Pane id="share-link" className="content" name={TABS.LINK}>
                <p>Copy the link below to share it</p>
                <CopyToClipboard value={url} />
              </Tabs.Pane>

              <Tabs.Pane className="content" id="share-embed" name={TABS.EMBED}>
                <p>Copy the embed code below to share it</p>
                <CopyToClipboard
                  value={`<iframe frameborder="0" width="960" height="600" src="${url.replace(
                    'map',
                    'embed/map',
                  )}"></iframe>`}
                />
              </Tabs.Pane>

              <Tabs.Pane className="content" id="share-oembed" name={TABS.OEMBED}>
                <p>Copy the oembed code below to share it</p>
                <CopyToClipboard value={`${origin}/services/oembed/?url=${url}`} />
              </Tabs.Pane>
            </Tabs>

            <div className="social-links">
              <div className="btn-social twitter">
                <a
                  href={`https://twitter.com/share?url=${url}`}
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  <svg className="icon">
                    <use xmlnsXlink="https://www.w3.org/1999/xlink" xlinkHref="#icon-twitter" />
                  </svg>
                </a>
              </div>
              <div className="btn-social facebook">
                <a
                  href={`https://www.facebook.com/sharer.php?u=${url}`}
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  <svg className="icon">
                    <use xmlnsXlink="https://www.w3.org/1999/xlink" xlinkHref="#icon-facebook" />
                  </svg>
                </a>
              </div>
              <div className="btn-social google">
                <a
                  href={`https://plus.google.com/share?url=${url}`}
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  <svg className="icon">
                    <use xmlnsXlink="https://www.w3.org/1999/xlink" xlinkHref="#icon-google" />
                  </svg>
                </a>
              </div>
            </div>
          </div>
        </div>
      </div>
    </ReactModal>
  );
};

export default ShareModal;
