import React, { useCallback } from 'react';
import cx from 'classnames';
import { DragDropContext, Droppable, Draggable } from 'react-beautiful-dnd';
import Loader from 'views/shared/Loader';
import InfoWindow from 'views/components/InfoWindow';
import { T } from '@transifex/react';
import { sortBy, useToggle, clickable } from 'utilities';
import LegendItem from './LegendItem';

const byOrder = sortBy('order', 'DESC');

const Legend = ({ activeLayers, reorder, loading, toggleLayer, setOpacity }) => {
  const [opened, toggleOpen] = useToggle(true);
  const onDragEnd = useCallback(
    ({ source, destination }) => destination && reorder(source.index, destination.index),
    [reorder],
  );

  return (
    <DragDropContext onDragEnd={onDragEnd}>
      <Droppable droppableId="legendLayers">
        {({ droppableProps, innerRef, placeholder }, { isDraggingOver }) => (
          <div className={cx('m-legend', { 'is-changing': isDraggingOver })}>
            <div className="wrapper">
              <header className={cx('m-legend__header', { 'is-minimize': !opened })}>
                <h2 className="title">
                  <T _str="Legend" />
                </h2>
                <span className="btn-minimize" {...clickable(toggleOpen)} />
              </header>

              <div className={cx('m-legend__content', { 'is-hidden': !opened })}>
                <Loader loading={loading} />

                <ul {...droppableProps} ref={innerRef} className="m-legend__list">
                  {activeLayers
                    .filter(Boolean)
                    .sort(byOrder)
                    .map((layer, index) => {
                      const { id, name, notAvailableByZoom, opacity, legend, info } = layer;
                      const { source, link } = info || {};
                      const layerVisible = opacity > 0;
                      return (
                        <Draggable key={id} draggableId={id} index={index}>
                          {({ draggableProps, dragHandleProps, innerRef: dragRef }) => (
                            <li
                              className={cx('drag-items', {
                                'is-not-available-by-zoom': notAvailableByZoom,
                              })}
                              data-id={id}
                              ref={dragRef}
                              {...draggableProps}
                              {...dragHandleProps}
                            >
                              <header>
                                <span className="draggable-icon">
                                  <svg>
                                    <use xlinkHref="#icon-drag" />
                                  </svg>
                                </span>

                                <h3>{name}</h3>

                                {id !== -1 && (
                                  <div className="actions">
                                    <button
                                      type="button"
                                      className="btn-info"
                                      {...clickable(() => {
                                        InfoWindow.show(name, info);
                                      })}
                                      data-layer-id={id}
                                    >
                                      <svg className="icon">
                                        <use xlinkHref="#icon-info" />
                                      </svg>
                                    </button>

                                    <button
                                      type="button"
                                      className={cx('btn-action', 'btn-visibility')}
                                      {...clickable(() => setOpacity(id, layerVisible ? 0 : 1))}
                                      data-id={id}
                                    >
                                      <svg>
                                        <use
                                          xlinkHref={`#icon-visibility${
                                            layerVisible ? 'on' : 'off'
                                          }`}
                                        />
                                      </svg>
                                    </button>

                                    <button
                                      type="button"
                                      className="btn-remove"
                                      {...clickable(() => toggleLayer(id))}
                                      data-layer-id={id}
                                    >
                                      <svg className="icon">
                                        <use xlinkHref="#icon-remove" />
                                      </svg>
                                    </button>
                                  </div>
                                )}
                              </header>
                              <LegendItem legend={legend} layer={layer} />
                              {source && (
                                <div className="source-container">
                                  <div className="source">
                                    <span className="source-bold">
                                      <T _str="Source:" />{' '}
                                    </span>
                                    <span>{source}</span>
                                  </div>
                                  <a
                                    className="source-link"
                                    target="_blank"
                                    rel="noopener noreferrer"
                                    href={link}
                                  >
                                    {link}
                                  </a>
                                </div>
                              )}
                            </li>
                          )}
                        </Draggable>
                      );
                    })}
                  {placeholder}
                </ul>
              </div>
            </div>
          </div>
        )}
      </Droppable>
    </DragDropContext>
  );
};

export default Legend;
