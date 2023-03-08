/* eslint-disable no-underscore-dangle */
import React, { Component } from 'react';
import ReactDOM from 'react-dom';
import DangerousHTML from 'react-dangerous-html';
import { clickable } from 'utilities';

export default class InfoWindow extends Component {
  static show(name, data) {
    if (InfoWindow.__instance) {
      InfoWindow.__instance.__show(name, data);
    } else {
      throw new Error(
        'There are no any instance of InfoWindow. You likely forgot to add it to your layout.',
      );
    }
  }

  static hide() {
    InfoWindow.__instance.__hide();
  }

  constructor(props) {
    super(props);
    InfoWindow.__instance = this;
  }

  state = {
    open: false,
    name: null,
    data: {},
  };

  __show = (name, data) => {
    this.setState({ open: true, name, data });
  };

  __hide = () => {
    this.setState({ open: false, name: null, data: {} });
  };

  render() {
    const {
      open,
      name,
      data: { description, source, link, links },
    } = this.state;

    if (!open) return null;

    return ReactDOM.createPortal(
      <div className="m-modal-window">
        <div className="modal-wrapper">
          <div className="btn-close" {...clickable(this.__hide)}>
            ×
          </div>
          <div className="modal-container">
            <h1>{name}</h1>

            <h4>Description</h4>
            <p>{description}</p>

            <h4>Source</h4>
            <div className="source">
              <DangerousHTML html={source} />

              {link && (
                <a className="link" target="_blank" rel="noopener noreferrer" href={link}>
                  {link}
                </a>
              )}

              {links &&
                links.map((lnk) => (
                  <a className="link" target="_blank" rel="noopener noreferrer" href={lnk}>
                    {lnk}
                  </a>
                ))}
            </div>
          </div>
        </div>
        <div className="modal-background" {...clickable(this.__hide)} />
      </div>,
      document.body,
    );
  }
}
