/**
 * Unit Tests for Layer Date Parameter Replacement
 * 
 * Tests the parseDates utility function from state/modules/layers/utils.js
 * which uses the resilience-layer-manager replace() function
 */

import { parseDates } from '../../../src/state/modules/layers/utils';

describe('Layer Utils - Date Parameter Replacement', () => {
  it('should replace date parameters in layer URLs', () => {
    const layer = {
      id: 1,
      name: 'Test Layer',
      timeline: {
        defaultDate: new Date('2023-01-15'),
      },
      layerConfig: {
        body: {
          url: 'https://example.com/tiles/{year}-{month}-{day}',
        },
      },
    };

    const result = parseDates(layer);
    
    expect(result.layerConfig.body.url).toBe('https://example.com/tiles/2023-01-15');
  });

  it('should replace date parameters in cartocss', () => {
    const layer = {
      id: 1,
      name: 'Test Layer',
      timeline: {
        defaultDate: new Date('2023-06-10'),
      },
      cartocss: '#layer { [date = "{year}-{month}-{day}"] { fill: red; } }',
      layerConfig: {
        body: {},
      },
    };

    const result = parseDates(layer);
    
    expect(result.cartocss).toContain('2023');
    expect(result.cartocss).toContain('06');
    expect(result.cartocss).toContain('10');
  });

  it('should replace date parameters in interactionConfig', () => {
    const layer = {
      id: 1,
      name: 'Test Layer',
      timeline: {
        defaultDate: new Date('2023-12-25'),
      },
      interactionConfig: 'SELECT * FROM table WHERE date = "{year}-{month}-{day}"',
      layerConfig: {
        body: {},
      },
    };

    const result = parseDates(layer);
    
    expect(result.interactionConfig).toContain('2023');
    expect(result.interactionConfig).toContain('12');
    expect(result.interactionConfig).toContain('25');
  });

  it('should use provided date parameter over default', () => {
    const layer = {
      id: 1,
      name: 'Test Layer',
      date: '2024-03-20',
      timeline: {
        defaultDate: new Date('2023-01-01'),
      },
      layerConfig: {
        body: {
          url: 'https://example.com/tiles/{year}-{month}-{day}',
        },
      },
    };

    const result = parseDates(layer, layer.date);
    
    expect(result.layerConfig.body.url).toContain('2024');
    expect(result.layerConfig.body.url).toContain('03');
    expect(result.layerConfig.body.url).toContain('20');
  });

  it('should handle cartodb layer types with multiple sublayers', () => {
    const layer = {
      id: 1,
      name: 'Test Cartodb Layer',
      type: 'cartodb',
      timeline: {
        defaultDate: new Date('2023-05-15'),
      },
      layerConfig: {
        body: {
          layers: [
            {
              options: {
                cartocss: '#layer { [date = "{year}-{month}"] { fill: blue; } }',
                sql: 'SELECT * FROM table WHERE year = {year}',
              },
            },
            {
              options: {
                cartocss: '#layer2 { [date = "{year}-{month}-{day}"] { fill: red; } }',
                sql: 'SELECT * FROM table2 WHERE date = "{year}-{month}-{day}"',
              },
            },
          ],
        },
      },
    };

    const result = parseDates(layer);
    
    expect(result.layerConfig.body.layers[0].options.cartocss).toContain('2023-05');
    expect(result.layerConfig.body.layers[0].options.sql).toContain('2023');
    expect(result.layerConfig.body.layers[1].options.cartocss).toContain('2023-05-15');
    expect(result.layerConfig.body.layers[1].options.sql).toContain('2023-05-15');
  });

  it('should preserve layer without timeline', () => {
    const layer = {
      id: 1,
      name: 'Static Layer',
      layerConfig: {
        body: {
          url: 'https://example.com/tiles/static',
        },
      },
    };

    const result = parseDates(layer);
    
    expect(result).toEqual(layer);
  });

  it('should pad month with leading zero', () => {
    const layer = {
      id: 1,
      name: 'Test Layer',
      timeline: {
        defaultDate: new Date('2023-03-05'),
      },
      layerConfig: {
        body: {
          url: 'https://example.com/tiles/{year}-{month}-{day}',
        },
      },
    };

    const result = parseDates(layer);
    
    // Month should be '03' not '3'
    expect(result.layerConfig.body.url).toBe('https://example.com/tiles/2023-03-05');
  });

  it('should handle analysisBody parameter replacement', () => {
    const layer = {
      id: 1,
      name: 'Analysis Layer',
      timeline: {
        defaultDate: new Date('2023-07-20'),
      },
      analysisBody: '{"year": {year}, "month": {month}, "day": {day}}',
      layerConfig: {
        body: {},
      },
    };

    const result = parseDates(layer);
    
    expect(result.analysisBody).toContain('2023');
    expect(result.analysisBody).toContain('07');
    expect(result.analysisBody).toContain('20');
  });
});

describe('Layer Utils - URL Persisted Keys', () => {
  it('should export correct URL persisted keys', () => {
    const { URL_PERSISTED_KEYS } = require('../../../src/state/modules/layers/utils');
    
    expect(URL_PERSISTED_KEYS).toEqual(['date', 'opacity', 'order', 'chartLimit']);
  });
});
