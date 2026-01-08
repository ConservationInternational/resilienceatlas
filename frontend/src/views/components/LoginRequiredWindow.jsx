/* eslint-disable no-underscore-dangle */
import React, { Component } from 'react';
import ReactDOM from 'react-dom';
import { clickable } from 'utilities';
import { T } from '@transifex/react';

export default class LoginRequiredWindow extends Component {
  static show() {
    if (LoginRequiredWindow.__instance) {
      LoginRequiredWindow.__instance.__show();
    } else {
      throw new Error(
        'There are no any instance of LoginRequiredWindow. You likely forgot to add it to your layout.',
      );
    }
  }

  static hide() {
    LoginRequiredWindow.__instance.__hide();
  }

  constructor(props) {
    super(props);
    LoginRequiredWindow.__instance = this;
  }

  state = {
    open: false,
  };

  __show = () => {
    this.setState({ open: true });
  };

  __hide = () => {
    this.setState({ open: false });
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
            <h4 style={{ 'text-align': 'center' }}>
              <T _str="Please login to enable download feature." />
            </h4>
          </div>
        </div>
        <div className="modal-background" {...clickable(this.__hide)} />
      </div>,
      document.body,
    );
  }
}
