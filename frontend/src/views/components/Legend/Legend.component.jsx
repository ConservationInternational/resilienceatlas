import React, { useCallback } from 'react';
import cx from 'classnames';
import { DragDropContext, Droppable, Draggable } from 'react-beautiful-dnd';
import Loader from '@shared/Loader';
import InfoWindow from '@components/InfoWindow';

import { sortBy, useToggle, clickable } from '@utilities';
import LegendItem from './LegendItem';

const byOrder = sortBy('order', 'DESC');

const Legend = ({
  activeLayers,
  reorder,
  loading,
  toggleLayer,
  setOpacity,
}) => {
  const [opened, toggleOpen] = useToggle(true);
  const onDragEnd = useCallback(
    ({ source, destination }) =>
      destination && reorder(source.index, destination.index),
    [],
  );

  return (
    <DragDropContext onDragEnd={onDragEnd}>
      <Droppable droppableId="legendLayers">
        {({ droppableProps, innerRef, placeholder }, { isDraggingOver }) => (
          <div className={cx('m-legend', { 'is-changing': isDraggingOver })}>
            <div className="wrapper">
              <header
                className={cx('m-legend__header', { 'is-minimize': !opened })}
              >
                <h2 className="title">Legend</h2>
                <span className="btn-minimize" {...clickable(toggleOpen)} />
              </header>

              <div
                className={cx('m-legend__content', { 'is-hidden': !opened })}
              >
                <Loader loading={loading} />

                <ul
                  {...droppableProps}
                  ref={innerRef}
                  className="m-legend__list"
                >
                  {activeLayers.sort(byOrder).map((layer, index) => {
                    const {
                      id,
                      name,
                      notAvailableByZoom,
                      opacity,
                      legend,
                      info,
                    } = layer;
                    const layerVisible = opacity > 0;

                    return (
                      <Draggable key={id} draggableId={id} index={index}>
                        {({
                          draggableProps,
                          dragHandleProps,
                          innerRef: dragRef,
                        }) => (
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
                                      InfoWindow.show(name, JSON.parse(info));
                                    })}
                                    data-layer-id={id}
                                  >
                                    <svg className="icon">
                                      <use xlinkHref="#icon-info" />
                                    </svg>
                                  </button>

                                  <button
                                    type="button"
                                    className={cx(
                                      'btn-action',
                                      'btn-visibility',
                                    )}
                                    {...clickable(() =>
                                      setOpacity(id, layerVisible ? 0 : 1),
                                    )}
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
