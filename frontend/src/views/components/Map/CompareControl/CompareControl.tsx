import React, { useCallback, useRef, useEffect, useState, useContext } from 'react';
import { createPortal } from 'react-dom';
import { useSelector, useDispatch } from 'react-redux';
import cx from 'classnames';
import { T } from '@transifex/react';
import {
  getCompareEnabled,
  getCompareReady,
  getLeftLayer,
  getRightLayer,
  getLeftLayerId,
  getRightLayerId,
  getSliderPosition,
  disableCompare,
  setSliderPosition,
} from 'state/modules/compare';
import { LayerManagerContext } from 'views/contexts/layerManagerCtx';
import type { RootState } from 'state/types';

interface CompareLayer {
  id: string | number;
  name: string;
}

interface CompareControlProps {
  map: L.Map;
}

/**
 * Gets the DOM container element for a Leaflet layer.
 * Different layer types have different ways to access their container.
 */
const getLayerContainer = (mapLayer: L.Layer | null): HTMLElement | null => {
  if (!mapLayer) return null;

  // TileLayer, GridLayer - most common
  if ('getContainer' in mapLayer && typeof mapLayer.getContainer === 'function') {
    return mapLayer.getContainer() as HTMLElement;
  }

  // FeatureGroup, LayerGroup - try to get container from child layers
  if ('getLayers' in mapLayer && typeof mapLayer.getLayers === 'function') {
    const childLayers = (mapLayer as L.LayerGroup).getLayers();
    for (const child of childLayers) {
      const container = getLayerContainer(child);
      if (container) return container;
    }
  }

  // Canvas layers
  if ('_container' in mapLayer && mapLayer._container) {
    return (mapLayer as unknown as { _container: HTMLElement })._container;
  }

  return null;
};

/**
 * CompareControl provides a side-by-side layer comparison feature.
 * Uses the CSS clip property with rect() values (like leaflet-side-by-side)
 * to split two map layers at a draggable slider position.
 */
const CompareControl: React.FC<CompareControlProps> = ({ map }) => {
  const dispatch = useDispatch();
  const layerManagerRef = useContext(LayerManagerContext);

  const enabled = useSelector(getCompareEnabled);
  const ready = useSelector(getCompareReady);
  const leftLayerId = useSelector(getLeftLayerId);
  const rightLayerId = useSelector(getRightLayerId);
  const leftLayer = useSelector((state: RootState) => getLeftLayer(state)) as CompareLayer | null;
  const rightLayer = useSelector((state: RootState) => getRightLayer(state)) as CompareLayer | null;
  const sliderPosition = useSelector(getSliderPosition);

  const containerRef = useRef<HTMLDivElement>(null);
  const sliderRef = useRef<HTMLDivElement>(null);
  const isDragging = useRef(false);
  const [localPosition, setLocalPosition] = useState(sliderPosition);

  // Track applied clips for cleanup
  const clipsApplied = useRef<{ left: HTMLElement | null; right: HTMLElement | null }>({
    left: null,
    right: null,
  });

  // Use ref to track current position for event handlers (avoids re-registering handlers)
  const positionRef = useRef(localPosition);
  useEffect(() => {
    positionRef.current = localPosition;
  }, [localPosition]);

  // Sync local position with redux state
  useEffect(() => {
    setLocalPosition(sliderPosition);
  }, [sliderPosition]);

  /**
   * Apply clip to layer DOM elements using the rect() approach.
   * This is a stable function that doesn't cause re-renders.
   * Returns true if clips were successfully applied.
   */
  const applyClips = useCallback(
    (position: number): boolean => {
      if (!layerManagerRef?.current?.layerManager || !map) return false;

      const layerManager = layerManagerRef.current.layerManager;
      const layers = layerManager.layers || [];

      // Find the left and right layer models
      const leftLayerModel = layers.find(
        (l: { id: string | number }) => String(l.id) === String(leftLayerId),
      );
      const rightLayerModel = layers.find(
        (l: { id: string | number }) => String(l.id) === String(rightLayerId),
      );

      // Get the actual DOM containers
      const leftContainer = getLayerContainer(leftLayerModel?.mapLayer);
      const rightContainer = getLayerContainer(rightLayerModel?.mapLayer);

      // Don't apply clip if containers are missing or the same element
      if (!leftContainer || !rightContainer || leftContainer === rightContainer) {
        return false;
      }

      // Calculate clip values using map container points
      const mapSize = map.getSize();
      const nw = map.containerPointToLayerPoint([0, 0]);
      const se = map.containerPointToLayerPoint(mapSize);
      const clipX = nw.x + (mapSize.x * position) / 100;

      // clip: rect(top, right, bottom, left) - all in pixels
      const leftClip = `rect(${nw.y}px, ${clipX}px, ${se.y}px, ${nw.x}px)`;
      const rightClip = `rect(${nw.y}px, ${se.x}px, ${se.y}px, ${clipX}px)`;

      // Apply the clip property
      leftContainer.style.clip = leftClip;
      rightContainer.style.clip = rightClip;

      // Store refs for cleanup
      clipsApplied.current.left = leftContainer;
      clipsApplied.current.right = rightContainer;

      return true;
    },
    [leftLayerId, rightLayerId, layerManagerRef, map],
  );

  /**
   * Apply clips when ready or position changes
   */
  useEffect(() => {
    if (!ready) {
      // Clean up any existing clips when not ready
      if (clipsApplied.current.left) {
        clipsApplied.current.left.style.clip = '';
        clipsApplied.current.left = null;
      }
      if (clipsApplied.current.right) {
        clipsApplied.current.right.style.clip = '';
        clipsApplied.current.right = null;
      }

      // Also clean up clips from all layers in the layer manager
      if (layerManagerRef?.current?.layerManager) {
        const layers = layerManagerRef.current.layerManager.layers || [];
        layers.forEach((layer: { mapLayer: L.Layer | null }) => {
          const container = getLayerContainer(layer.mapLayer);
          if (container) {
            container.style.clip = '';
          }
        });
      }

      // Force map to redraw
      if (map) {
        map.invalidateSize();
      }
      return;
    }

    applyClips(localPosition);
  }, [ready, localPosition, applyClips, layerManagerRef, map]);

  // Retry applying clips when layers are first loading (for URL-shared comparison links)
  // The layer containers may not be available immediately on page load
  useEffect(() => {
    if (!ready || !map) return;

    // Check if clips have been successfully applied
    if (clipsApplied.current.left && clipsApplied.current.right) {
      return; // Already applied, no need to retry
    }

    // Try immediately
    const success = applyClips(positionRef.current);
    if (success) return;

    // Listen for layer add events - this fires when layers are added to the map
    const onLayerAdd = () => {
      // Small delay to ensure DOM is updated
      setTimeout(() => {
        if (!clipsApplied.current.left || !clipsApplied.current.right) {
          applyClips(positionRef.current);
        }
      }, 100);
    };

    map.on('layeradd', onLayerAdd);

    // Use MutationObserver to watch for new tile layers being added to the DOM
    const mapContainer = map.getContainer();
    let observer: MutationObserver | null = null;

    if (mapContainer) {
      observer = new MutationObserver(() => {
        if (!clipsApplied.current.left || !clipsApplied.current.right) {
          applyClips(positionRef.current);
        }
      });

      observer.observe(mapContainer, {
        childList: true,
        subtree: true,
      });
    }

    // Set up a retry mechanism as fallback
    let retryCount = 0;
    const maxRetries = 40;

    const retryInterval = setInterval(() => {
      retryCount++;
      const success = applyClips(positionRef.current);

      if (success || retryCount >= maxRetries) {
        clearInterval(retryInterval);
      }
    }, 500);

    return () => {
      map.off('layeradd', onLayerAdd);
      if (observer) {
        observer.disconnect();
      }
      clearInterval(retryInterval);
    };
  }, [ready, map, applyClips]);

  // Update clips when map moves (panning/zooming changes layer point coordinates)
  // Uses refs to avoid re-registering handlers on every position change
  useEffect(() => {
    if (!ready || !map) return;

    const updateClipsOnMove = () => {
      // Use the ref to get current position without causing re-renders
      applyClips(positionRef.current);
    };

    map.on('move', updateClipsOnMove);
    map.on('zoom', updateClipsOnMove);

    return () => {
      map.off('move', updateClipsOnMove);
      map.off('zoom', updateClipsOnMove);
    };
  }, [ready, map, applyClips]);

  // Cleanup clips when compare mode is disabled
  useEffect(() => {
    if (!enabled) {
      // Clean up any existing clips
      if (clipsApplied.current.left) {
        clipsApplied.current.left.style.clip = '';
        clipsApplied.current.left = null;
      }
      if (clipsApplied.current.right) {
        clipsApplied.current.right.style.clip = '';
        clipsApplied.current.right = null;
      }

      // Also clean up clips from all layers in the layer manager
      // This handles cases where the tracked refs might be stale
      if (layerManagerRef?.current?.layerManager) {
        const layers = layerManagerRef.current.layerManager.layers || [];
        layers.forEach((layer: { mapLayer: L.Layer | null }) => {
          const container = getLayerContainer(layer.mapLayer);
          if (container) {
            container.style.clip = '';
          }
        });
      }

      // Force map to redraw tiles
      if (map) {
        map.invalidateSize();
      }
    }

    // Cleanup function to run when component unmounts or effect re-runs
    return () => {
      if (clipsApplied.current.left) {
        clipsApplied.current.left.style.clip = '';
      }
      if (clipsApplied.current.right) {
        clipsApplied.current.right.style.clip = '';
      }
    };
  }, [enabled, layerManagerRef, map]);

  // Also cleanup when layer IDs change (layer toggled off or removed)
  useEffect(() => {
    // If either layer ID becomes null/undefined, clean up all clips
    if (!leftLayerId || !rightLayerId) {
      if (clipsApplied.current.left) {
        clipsApplied.current.left.style.clip = '';
        clipsApplied.current.left = null;
      }
      if (clipsApplied.current.right) {
        clipsApplied.current.right.style.clip = '';
        clipsApplied.current.right = null;
      }

      // Clean all layer clips as fallback
      if (layerManagerRef?.current?.layerManager) {
        const layers = layerManagerRef.current.layerManager.layers || [];
        layers.forEach((layer: { mapLayer: L.Layer | null }) => {
          const container = getLayerContainer(layer.mapLayer);
          if (container) {
            container.style.clip = '';
          }
        });
      }
    }
  }, [leftLayerId, rightLayerId, layerManagerRef]);

  const handleMove = useCallback((clientX: number) => {
    if (!containerRef.current || !isDragging.current) return;

    const rect = containerRef.current.getBoundingClientRect();
    const x = clientX - rect.left;
    const percentage = Math.min(100, Math.max(0, (x / rect.width) * 100));

    setLocalPosition(percentage);
  }, []);

  const handleEnd = useCallback(() => {
    if (isDragging.current) {
      isDragging.current = false;
      dispatch(setSliderPosition(localPosition));
      document.body.style.cursor = '';
      document.body.style.userSelect = '';
      // Re-enable map dragging
      if (map) {
        map.dragging.enable();
      }
    }
  }, [dispatch, localPosition, map]);

  const handleMouseDown = useCallback(
    (e: React.MouseEvent) => {
      e.preventDefault();
      e.stopPropagation();
      isDragging.current = true;
      document.body.style.cursor = 'ew-resize';
      document.body.style.userSelect = 'none';
      // Disable map dragging while using slider
      if (map) {
        map.dragging.disable();
      }
    },
    [map],
  );

  const handleTouchStart = useCallback(
    (e: React.TouchEvent) => {
      e.preventDefault();
      e.stopPropagation();
      isDragging.current = true;
      document.body.style.userSelect = 'none';
      // Disable map dragging while using slider
      if (map) {
        map.dragging.disable();
      }
    },
    [map],
  );

  // Global mouse/touch event listeners
  useEffect(() => {
    const handleMouseMove = (e: MouseEvent) => handleMove(e.clientX);
    const handleTouchMove = (e: TouchEvent) => {
      if (e.touches[0]) handleMove(e.touches[0].clientX);
    };

    document.addEventListener('mousemove', handleMouseMove);
    document.addEventListener('mouseup', handleEnd);
    document.addEventListener('touchmove', handleTouchMove);
    document.addEventListener('touchend', handleEnd);

    return () => {
      document.removeEventListener('mousemove', handleMouseMove);
      document.removeEventListener('mouseup', handleEnd);
      document.removeEventListener('touchmove', handleTouchMove);
      document.removeEventListener('touchend', handleEnd);
    };
  }, [handleMove, handleEnd]);

  // Keyboard navigation for accessibility
  const handleKeyDown = useCallback(
    (e: React.KeyboardEvent) => {
      const step = e.shiftKey ? 10 : 2;
      let newPosition = localPosition;

      if (e.key === 'ArrowLeft') {
        newPosition = Math.max(0, localPosition - step);
      } else if (e.key === 'ArrowRight') {
        newPosition = Math.min(100, localPosition + step);
      } else {
        return;
      }

      e.preventDefault();
      setLocalPosition(newPosition);
      dispatch(setSliderPosition(newPosition));
    },
    [dispatch, localPosition],
  );

  const handleClose = useCallback(() => {
    dispatch(disableCompare());
  }, [dispatch]);

  // Don't render if compare mode is not enabled
  if (!enabled) return null;

  // Get the map container for portal rendering
  const mapContainer = map?.getContainer();

  const controlContent = (
    <div
      className={cx('c-compare-control', { 'is-ready': ready })}
      ref={containerRef}
      style={{
        position: 'absolute',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        zIndex: 9999,
        pointerEvents: 'none',
      }}
    >
      {/* Instructions when layers not yet selected */}
      {!ready && (
        <div
          style={{
            position: 'absolute',
            top: '16px',
            left: '50%',
            transform: 'translateX(-50%)',
            zIndex: 10000,
            pointerEvents: 'auto',
          }}
        >
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '12px',
              background: 'rgba(0, 0, 0, 0.85)',
              color: '#fff',
              padding: '12px 16px',
              borderRadius: '8px',
              fontSize: '14px',
              boxShadow: '0 4px 12px rgba(0, 0, 0, 0.3)',
              maxWidth: '90vw',
              textAlign: 'center',
            }}
          >
            <T _str="Select two layers to compare using the compare icons in the legend" />
            <button
              type="button"
              onClick={handleClose}
              aria-label="Close compare mode"
              style={{
                background: 'transparent',
                border: 'none',
                color: '#fff',
                cursor: 'pointer',
                padding: '4px',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                opacity: 0.7,
                flexShrink: 0,
              }}
            >
              <span style={{ fontSize: '18px' }}>✕</span>
            </button>
          </div>
        </div>
      )}

      {/* Comparison slider and labels when ready */}
      {ready && (
        <>
          {/* Slider handle */}
          <div
            className="compare-slider"
            style={{
              position: 'absolute',
              left: `${localPosition}%`,
              top: 0,
              bottom: 0,
              width: '40px',
              transform: 'translateX(-50%)',
              cursor: 'ew-resize',
              pointerEvents: 'auto',
              zIndex: 10001,
            }}
            ref={sliderRef}
            onMouseDown={handleMouseDown}
            onTouchStart={handleTouchStart}
            onKeyDown={handleKeyDown}
            role="slider"
            aria-label="Layer comparison slider"
            aria-valuenow={Math.round(localPosition)}
            aria-valuemin={0}
            aria-valuemax={100}
            tabIndex={0}
          >
            {/* Vertical line */}
            <div
              style={{
                position: 'absolute',
                top: 0,
                bottom: 0,
                left: '50%',
                width: '4px',
                transform: 'translateX(-50%)',
                background: '#fff',
                boxShadow: '0 0 8px rgba(0, 0, 0, 0.5)',
              }}
            />

            {/* Left layer label - rotated vertical text */}
            <div
              style={{
                position: 'absolute',
                top: '50%',
                right: '100%',
                marginRight: '2px',
                transform: 'translateY(-50%) rotate(-90deg)',
                transformOrigin: 'center center',
                background: 'rgba(0, 0, 0, 0.75)',
                color: '#fff',
                padding: '6px 12px',
                borderRadius: '4px',
                fontSize: '11px',
                fontWeight: 500,
                whiteSpace: 'nowrap',
                pointerEvents: 'none',
              }}
            >
              {leftLayer?.name}
            </div>

            {/* Right layer label - rotated vertical text */}
            <div
              style={{
                position: 'absolute',
                top: '50%',
                left: '100%',
                marginLeft: '2px',
                transform: 'translateY(-50%) rotate(90deg)',
                transformOrigin: 'center center',
                background: 'rgba(0, 0, 0, 0.75)',
                color: '#fff',
                padding: '6px 12px',
                borderRadius: '4px',
                fontSize: '11px',
                fontWeight: 500,
                whiteSpace: 'nowrap',
                pointerEvents: 'none',
              }}
            >
              {rightLayer?.name}
            </div>

            {/* Circular handle */}
            <div
              style={{
                position: 'absolute',
                top: '50%',
                left: '50%',
                transform: 'translate(-50%, -50%)',
                width: '40px',
                height: '40px',
                background: '#fff',
                borderRadius: '50%',
                boxShadow: '0 2px 8px rgba(0, 0, 0, 0.3)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              {/* Arrows */}
              <div style={{ display: 'flex', alignItems: 'center', gap: '4px', color: '#333' }}>
                <span style={{ fontSize: '12px' }}>◀</span>
                <span style={{ fontSize: '12px' }}>▶</span>
              </div>
            </div>
          </div>

          {/* Close button */}
          <button
            type="button"
            onClick={handleClose}
            aria-label="Exit compare mode"
            title="Close comparison"
            style={{
              position: 'absolute',
              top: '160px',
              right: '16px',
              width: '36px',
              height: '36px',
              background: 'rgba(0, 0, 0, 0.75)',
              border: 'none',
              borderRadius: '50%',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: '#fff',
              pointerEvents: 'auto',
              zIndex: 10002,
            }}
          >
            <span style={{ fontSize: '18px', lineHeight: 1 }}>✕</span>
          </button>
        </>
      )}
    </div>
  );

  // Use portal to render into the Leaflet map container for proper positioning
  if (mapContainer) {
    return createPortal(controlContent, mapContainer);
  }

  // Fallback to inline rendering if no map container available
  return controlContent;
};

export default CompareControl;
