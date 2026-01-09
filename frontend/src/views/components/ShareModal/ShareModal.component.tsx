import { useCallback, useMemo, useState } from 'react';
import ReactModal from 'react-modal';
import cx from 'classnames';
import axios from 'axios';
import { useRouter } from 'next/router';
import { useQuery } from '@tanstack/react-query';
import { T } from '@transifex/react';
import Tabs from 'views/shared/Tabs';
import LinkButton from 'views/shared/LinkButton';
import CopyToClipboard from 'views/shared/CopyToClipboard';

import type { SharedURLPayload } from 'types/shared-url';

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
  const embedUrl = url.replace('map', 'embed/map');

  // Generating shorten URL
  const { data: shortenUrlData } = useQuery<SharedURLPayload>({
    queryKey: ['url-shortener', url],
    queryFn: () =>
      axios({
        method: 'POST',
        url: `${process.env.NEXT_PUBLIC_API_HOST}/api/share`,
        data: {
          body: url,
        },
      }).then((res) => res.data),
    enabled: isOpen,
  });

  // Generating shorten URL for embed
  const { data: shortenEmbedUrlData } = useQuery<SharedURLPayload>({
    queryKey: ['url-shortener-embed', embedUrl],
    queryFn: () =>
      axios({
        method: 'POST',
        url: `${process.env.NEXT_PUBLIC_API_HOST}/api/share`,
        data: {
          body: embedUrl,
        },
      }).then((res) => res.data),
    enabled: isOpen,
  });

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

  const shortenUrl = useMemo(() => {
    if (!shortenUrlData) return url;
    return `${origin}/share/${shortenUrlData.uid}`;
  }, [origin, shortenUrlData, url]);

  const shortenEmbedUrl = useMemo(() => {
    if (!shortenEmbedUrlData) return embedUrl;
    return `${origin}/share/${shortenEmbedUrlData.uid}`;
  }, [embedUrl, origin, shortenEmbedUrlData]);

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
              <h2>
                <T _str="Share" />
              </h2>

              <ul className="tabs tabs-secondary-content">
                <li className={cx('tab-title', { active: tab === TABS.LINK })}>
                  <LinkButton data-tab={TABS.LINK} onClick={switchTab}>
                    <T _str="Link" />
                  </LinkButton>
                </li>
                <li className={cx('tab-title', { active: tab === TABS.EMBED })}>
                  <LinkButton data-tab={TABS.EMBED} onClick={switchTab}>
                    <T _str="Embed" />
                  </LinkButton>
                </li>
                <li className={cx('tab-title', { active: tab === TABS.OEMBED })}>
                  <LinkButton data-tab={TABS.OEMBED} onClick={switchTab}>
                    <T _str="OEmbed" />
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
                <p>
                  <T _str="Copy the link below to share it" />
                </p>
                <CopyToClipboard value={shortenUrl} />
              </Tabs.Pane>

              <Tabs.Pane className="content" id="share-embed" name={TABS.EMBED}>
                <p>
                  <T _str="Copy the embed code below to share it" />
                </p>
                <CopyToClipboard
                  value={`<iframe frameborder="0" width="960" height="600" src="${shortenEmbedUrl}"></iframe>`}
                />
              </Tabs.Pane>

              <Tabs.Pane className="content" id="share-oembed" name={TABS.OEMBED}>
                <p>
                  <T _str="Copy the oembed code below to share it" />
                </p>
                <CopyToClipboard value={`${origin}/services/oembed/?url=${shortenUrl}`} />
              </Tabs.Pane>
            </Tabs>

            <div className="social-links">
              <div className="btn-social twitter">
                <a
                  href={`https://twitter.com/share?url=${shortenUrl}`}
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
                  href={`https://www.facebook.com/sharer.php?u=${shortenUrl}`}
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
                  href={`https://plus.google.com/share?url=${shortenUrl}`}
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

ReactModal.setAppElement('#root');

export default ShareModal;
