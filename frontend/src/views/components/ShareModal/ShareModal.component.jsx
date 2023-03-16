/* eslint-disable no-underscore-dangle */
import React, { Component } from 'react';
import ReactDOM from 'react-dom';
import cx from 'classnames';

import Tabs from 'views/shared/Tabs';
import LinkButton from 'views/shared/LinkButton';
import CopyToClipboard from 'views/shared/CopyToClipboard';

import { clickable } from 'utilities';

const TABS = {
  LINK: 'share-link',
  EMBED: 'share-embed',
  OEMBED: 'share-oembed',
};

export default class ShareModal extends Component {
  static show() {
    if (ShareModal.__instance) {
      ShareModal.__instance.__show();
    } else {
      throw new Error(
        'There are no any instance of ShareModal. You likely forgot to add it to your layout.',
      );
    }
  }

  static hide() {
    ShareModal.__instance.__hide();
  }

  constructor(props) {
    super(props);
    ShareModal.__instance = this;
  }

  state = {
    open: false,
    tab: TABS.LINK,
  };

  __show = () => {
    this.setState({ open: true });
  };

  __hide = () => {
    this.setState({ open: false });
  };

  switchTab = (e) => {
    const { tab } = this.state;
    const newTab = e.currentTarget.dataset.tab;

    if (tab !== newTab) {
      this.setState({ tab: newTab });
    }
  };

  render() {
    const { open, tab } = this.state;

    if (!open) return null;

    const url = window.location.href;

    return ReactDOM.createPortal(
      <div className="m-modal-window m-share">
        <div className="modal-wrapper">
          <div className="btn-close-modal" {...clickable(this.__hide)}>
            ×
          </div>
          <div className="modal-container is-loading-share">
            <div className="modal-content">
              <div className="share-nav">
                <h2>Share</h2>

                <ul className="tabs tabs-secondary-content">
                  <li className={cx('tab-title', { active: tab === TABS.LINK })}>
                    <LinkButton data-tab={TABS.LINK} onClick={this.switchTab}>
                      Link
                    </LinkButton>
                  </li>
                  <li className={cx('tab-title', { active: tab === TABS.EMBED })}>
                    <LinkButton data-tab={TABS.EMBED} onClick={this.switchTab}>
                      Embed
                    </LinkButton>
                  </li>
                  <li className={cx('tab-title', { active: tab === TABS.OEMBED })}>
                    <LinkButton data-tab={TABS.OEMBED} onClick={this.switchTab}>
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
                  <CopyToClipboard
                    value={`${window.location.origin}/services/oembed/?url=${window.location.href}`}
                  />
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
        <div className="modal-background" {...clickable(this.__hide)} />
      </div>,
      document.body,
    );
  }
}
