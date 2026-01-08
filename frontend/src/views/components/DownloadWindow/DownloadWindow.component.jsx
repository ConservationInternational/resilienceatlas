/* eslint-disable no-underscore-dangle */
import React, { Component } from 'react';
import ReactDOM from 'react-dom';
import cx from 'classnames';
import { T } from '@transifex/react';

import { clickable } from 'utilities';

import { event } from 'utilities/ga';

export default class DownloadWindow extends Component {
  static show(url, category_name, label) {
    if (DownloadWindow.__instance) {
      DownloadWindow.__instance.__show(url, category_name, label);
    } else {
      throw new Error(
        'There are no any instance of DownloadWindow. You likely forgot to add it to your layout.',
      );
    }
  }

  static hide() {
    DownloadWindow.__instance.__hide();
  }

  constructor(props) {
    super(props);
    DownloadWindow.__instance = this;
  }

  state = {
    open: false,
    terms_accepted: localStorage.getItem('terms_accepted'),
    url: '',
  };

  __show = (url, category_name, label) => {
    this.setState({ open: true, url, category_name, label });
  };

  __hide = () => {
    this.setState({ open: false, url: null });
  };

  acceptTerms = (e) => {
    const { checked } = e.target;

    this.setState(
      {
        terms_accepted: checked,
      },
      () => {
        localStorage.setItem('terms_accepted', checked);
      },
    );
  };

  renderTerms = () => {
    const { url, terms_accepted } = this.state;

    return (
      <>
        <p>
          <T
            _str="Before download any data, you need to read and accept our {terms_of_use}."
            terms_of_use={
              <a className="theme-color" href="http://www.conservation.org/pages/terms.aspx">
                <T
                  _str="terms of use"
                  _comment={
                    'Before download any data, you need to read and accept our {terms_of_use}.'
                  }
                />
              </a>
            }
          />
        </p>
        <input type="checkbox" id="terms-and-conditions" onChange={this.acceptTerms} />
        <label htmlFor="terms-and-conditions">
          <T _str="I have read and accepted the Conservation International terms of use" />
        </label>
        <a
          href={url}
          className={cx('btn', 'btn-secondary', 'theme-bg-color', 'btn-download-infowindow', {
            '-disabled': !terms_accepted,
          })}
        >
          <T _str="Download data" />
        </a>
      </>
    );
  };

  renderContent = () => {
    const { terms_accepted, url, category_name, label } = this.state;

    if (!terms_accepted) {
      return this.renderTerms();
    }

    return (
      <>
        <p>
          <T _str="Click to continue with download" />
        </p>

        <a
          href={url}
          className={cx('btn', 'btn-secondary', 'theme-bg-color', 'btn-download-infowindow', {
            '-disabled': !terms_accepted,
          })}
          onClick={(e) => {
            e.preventDefault();
            e.stopPropagation();
            event({ action: 'download', params: { category: category_name, label } });
          }}
        >
          <T _str="Download data" />
        </a>
      </>
    );
  };

  render() {
    const { open } = this.state;

    if (!open) return null;

    return ReactDOM.createPortal(
      <div className="m-modal-window">
        <div className="modal-wrapper">
          <div className="btn-close" {...clickable(this.__hide)}>
            ×
          </div>
          <div className="modal-container">
            <h1>
              <T _str="Download" />
            </h1>

            {this.renderContent()}
          </div>
        </div>
        <div className="modal-background" {...clickable(this.__hide)} />
      </div>,
      document.body,
    );
  }
}
