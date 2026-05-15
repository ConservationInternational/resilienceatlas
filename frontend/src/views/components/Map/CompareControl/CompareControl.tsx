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
import type OlMap from 'ol/Map';
import type Layer from 'ol/layer/Layer';
import DragPan from 'ol/interaction/DragPan';

interface CompareLayer {
  id: string | number;
  name: string;
}

interface CompareControlProps {
  map: OlMap;
}

/**
 * CompareControl provides a side-by-side layer comparison feature.
 * Uses OL prerender/postrender canvas clipping to split two layers at
 * a draggable slider position.
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

  // Store canvas clip handlers so we can un() them when layers change
  const clipHandlers = useRef<{
    left: { pre: () => void; post: () => void; layer: Layer } | null;
    right: { pre: () => void; post: () => void; layer: Layer } | null;
  }>({ left: null, right: null });

  // Use ref for position so prerender handlers always use the latest value
  const positionRef = useRef(localPosition);
  useEffect(() => {
    positionRef.current = localPosition;
  }, [localPosition]);

  // Sync local position with redux state
  useEffect(() => {
    setLocalPosition(sliderPosition);
  }, [sliderPosition]);

  /**
   * Remove canvas clip listeners from both OL layers.
   */
  const removeClipHandlers = useCallback(() => {
    const { left, right } = clipHandlers.current;
    if (left) {
      left.layer.un('prerender', left.pre as never);
      left.layer.un('postrender', left.post as never);
      clipHandlers.current.left = null;
    }
    if (right) {
      right.layer.un('prerender', right.pre as never);
      right.layer.un('postrender', right.post as never);
      clipHandlers.current.right = null;
    }
    // Force a map render so the clip is visually removed
    map?.render();
  }, [map]);

  /**
   * Attach canvas prerender/postrender listeners to the left and right OL layers.
   * The prerender handler clips the canvas to the appropriate half.
   */
  const applyClips = useCallback(() => {
    if (!layerManagerRef?.current?.layerManager || !map) return false;

    const layers = layerManagerRef.current.layerManager.layers || [];
    const leftModel = layers.find(
      (l: { id: string | number }) => String(l.id) === String(leftLayerId),
    );
    const rightModel = layers.find(
      (l: { id: string | number }) => String(l.id) === String(rightLayerId),
    );

    const leftMapLayer = leftModel?.mapLayer as Layer | null;
    const rightMapLayer = rightModel?.mapLayer as Layer | null;

    if (!leftMapLayer || !rightMapLayer || leftMapLayer === rightMapLayer) return false;

    // Remove any existing handlers first
    removeClipHandlers();

    // OL prerender events receive the render event object
    const makeOlPrerender =
      (side: 'left' | 'right') => (event: { context: CanvasRenderingContext2D }) => {
        const ctx = event.context;
        const canvasWidth = ctx.canvas.width;
        const canvasHeight = ctx.canvas.height;
        const clipX = (canvasWidth * positionRef.current) / 100;
        ctx.save();
        ctx.beginPath();
        if (side === 'left') {
          ctx.rect(0, 0, clipX, canvasHeight);
        } else {
          ctx.rect(clipX, 0, canvasWidth - clipX, canvasHeight);
        }
        ctx.clip();
      };

    const makeOlPostrender = () => (event: { context: CanvasRenderingContext2D }) => {
      event.context.restore();
    };

    const leftPre = makeOlPrerender('left');
    const leftPost = makeOlPostrender();
    const rightPre = makeOlPrerender('right');
    const rightPost = makeOlPostrender();

    leftMapLayer.on('prerender', leftPre as never);
    leftMapLayer.on('postrender', leftPost as never);
    rightMapLayer.on('prerender', rightPre as never);
    rightMapLayer.on('postrender', rightPost as never);

    clipHandlers.current.left = {
      pre: leftPre as () => void,
      post: leftPost as () => void,
      layer: leftMapLayer,
    };
    clipHandlers.current.right = {
      pre: rightPre as () => void,
      post: rightPost as () => void,
      layer: rightMapLayer,
    };

    map.render();
    return true;
  }, [leftLayerId, rightLayerId, layerManagerRef, map, removeClipHandlers]);

  // Re-apply clips when position changes (force map render so prerender fires)
  useEffect(() => {
    if (ready && clipHandlers.current.left && clipHandlers.current.right) {
      map?.render();
    }
  }, [localPosition, ready, map]);

  /**
   * Apply/remove clips when compare ready state changes
   */
  useEffect(() => {
    if (!ready) {
      removeClipHandlers();
      if (map) map.updateSize();
      return;
    }
    applyClips();
  }, [ready, applyClips, removeClipHandlers, map]);

  // Retry applying clips (layers may not be ready on first render)
  useEffect(() => {
    if (!ready || !map) return;
    if (clipHandlers.current.left && clipHandlers.current.right) return;

    const success = applyClips();
    if (success) return;

    // Retry via MutationObserver when DOM changes
    let retryCount = 0;
    const maxRetries = 40;
    const retryInterval = setInterval(() => {
      retryCount++;
      const ok = applyClips();
      if (ok || retryCount >= maxRetries) clearInterval(retryInterval);
    }, 500);

    return () => clearInterval(retryInterval);
  }, [ready, map, applyClips]);

  // Cleanup when compare mode is disabled or layer IDs change
  useEffect(() => {
    if (!enabled) {
      removeClipHandlers();
      if (map) map.updateSize();
    }
  }, [enabled, removeClipHandlers, map]);

  useEffect(() => {
    if (!leftLayerId || !rightLayerId) {
      removeClipHandlers();
    }
  }, [leftLayerId, rightLayerId, removeClipHandlers]);

  // Re-apply clips when layer IDs change (user picked different layers)
  useEffect(() => {
    if (ready && leftLayerId && rightLayerId) {
      applyClips();
    }
  }, [ready, leftLayerId, rightLayerId, applyClips]);

  // Cleanup on unmount
  useEffect(() => {
    return () => removeClipHandlers();
  }, [removeClipHandlers]);

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
      // Re-enable map panning
      if (map) {
        map.getInteractions().forEach((interaction) => {
          if (interaction instanceof DragPan) interaction.setActive(true);
        });
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
      // Disable map panning while using slider
      if (map) {
        map.getInteractions().forEach((interaction) => {
          if (interaction instanceof DragPan) interaction.setActive(false);
        });
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
      // Disable map panning while using slider
      if (map) {
        map.getInteractions().forEach((interaction) => {
          if (interaction instanceof DragPan) interaction.setActive(false);
        });
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
  const mapContainer = map?.getTargetElement() as HTMLElement | null;

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

  // Use portal to render into the OL map container for proper positioning
  if (mapContainer) {
    return createPortal(controlContent, mapContainer);
  }

  // Fallback to inline rendering if no map container available
  return controlContent;
};

export default CompareControl;
