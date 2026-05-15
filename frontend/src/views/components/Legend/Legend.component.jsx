import React, { useCallback } from 'react';
import cx from 'classnames';
import { DragDropContext, Droppable, Draggable } from '@hello-pangea/dnd';
import Loader from 'views/shared/Loader';
import InfoWindow from 'views/components/InfoWindow';
import { T, useT } from '@transifex/react';
import { useToggle, clickable } from 'utilities';
import LegendItem from './LegendItem';
import LegendTimeline from './LegendTimeline';

const Legend = ({
  activeLayers,
  reorder,
  loading,
  toggleLayer,
  setOpacity,
  defaultEmbedURLLayerParams,
  isEmbed,
  compareEnabled,
  compareLeftLayerId,
  compareRightLayerId,
  toggleCompareLayer,
}) => {
  const [opened, toggleOpen] = useToggle(true);
  const t = useT();

  // Check if compare mode is ready (both layers selected)
  const compareReady = compareEnabled && compareLeftLayerId && compareRightLayerId;

  const onDragEnd = useCallback(
    ({ source, destination }) => {
      if (!destination) return;

      // When compare mode is active with both layers, prevent:
      // 1. Moving comparison layers (indices 0 and 1)
      // 2. Moving other layers into the comparison positions (0 or 1)
      if (compareReady) {
        const srcIndex = source.index;
        const destIndex = destination.index;

        // Prevent moving comparison layers
        if (srcIndex === 0 || srcIndex === 1) return;

        // Prevent moving other layers into comparison slots
        if (destIndex === 0 || destIndex === 1) return;
      }

      reorder(source.index, destination.index);
    },
    [reorder, compareReady],
  );

  // Helper to determine compare status for a layer
  const getCompareStatus = useCallback(
    (layerId) => {
      if (compareLeftLayerId === layerId) return 'left';
      if (compareRightLayerId === layerId) return 'right';
      return null;
    },
    [compareLeftLayerId, compareRightLayerId],
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
                  {(activeLayers || []).filter(Boolean).map((layer, index) => {
                    const { id, name, notAvailableByZoom, legend, info, timeline } = layer;

                    const defaultParams = defaultEmbedURLLayerParams?.find(
                      (l) => l.id === layer.id,
                    );
                    const date = layer.date || defaultParams?.date;
                    const opacity = layer.opacity || defaultParams?.opacity;

                    const { source, link } = info || {};
                    const layerVisible = opacity > 0;
                    const compareStatus = getCompareStatus(id);

                    // Disable dragging for comparison layers when compare mode is active
                    const isDragDisabled = compareReady && (index === 0 || index === 1);

                    return (
                      <Draggable
                        key={id}
                        draggableId={String(id)}
                        index={index}
                        isDragDisabled={isDragDisabled}
                      >
                        {({ draggableProps, dragHandleProps, innerRef: dragRef }) => (
                          <li
                            className={cx('drag-items', {
                              'is-not-available-by-zoom': notAvailableByZoom,
                              'is-compare-left': compareStatus === 'left',
                              'is-compare-right': compareStatus === 'right',
                              'is-drag-disabled': isDragDisabled,
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
                                  {/* Compare button */}
                                  <button
                                    type="button"
                                    className={cx('btn-action', 'btn-compare', {
                                      'is-active': compareStatus !== null,
                                      'is-left': compareStatus === 'left',
                                      'is-right': compareStatus === 'right',
                                    })}
                                    {...clickable(() => toggleCompareLayer(id))}
                                    data-layer-id={id}
                                    title={
                                      compareStatus
                                        ? t('Remove from comparison')
                                        : t('Add to comparison')
                                    }
                                  >
                                    {compareStatus && (
                                      <span className="compare-badge">
                                        {compareStatus === 'left' ? 'L' : 'R'}
                                      </span>
                                    )}
                                    <svg className="icon">
                                      <use xlinkHref="#icon-compare" />
                                    </svg>
                                  </button>

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

                                  {!isEmbed && (
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
                                  )}

                                  {!isEmbed && (
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
                                  )}
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
                            {timeline && (
                              <LegendTimeline
                                selectedDate={date}
                                layerId={id}
                                layerName={name}
                                timeline={timeline}
                              />
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
