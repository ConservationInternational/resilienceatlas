(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.Helper = root.app.Helper || {};

  root.app.Helper.Charts = root.app.Helper.Class.extend({

    initialize: function() {

    },

    buildPieChart: function(params) {
      var elem = params.elem;
      var elemAttr = elem.replace(/[#]|[.]/g, '');
      var $el = $(elem);
      var contentWidth = params.contentWidth;
      var contentHeight = params.contentHeight;
      var data = params.data;
      var hover = params.hover;
      var loader = params.loader || null;
      var unit = params.unit || '';
      var decimals = params.decimals || 0;
      var marginParams = params.margin || {};
      var margin = {top: marginParams.top || 0, left: marginParams.left || 0,
                    bottom: marginParams.bottom || 0, right: marginParams.right || 0 };
      var duration = params.duration || 0;

      var width = contentWidth - margin.left - margin.right,
          height = contentHeight - margin.top - margin.bottom,
          radius = Math.min(width-20, height-20) / 2;

      var arc = d3.svg.arc()
          .outerRadius(radius - 5)
          .innerRadius(radius - 60);

      var pie = d3.layout.pie()
          .sort(null)
          .value(function(d) { return d.value; });

      var svg = d3.select(elem).append('svg')
          .attr('width', width)
          .attr('height', height);

      function tweenPie(finish) {
        var start = {
          startAngle: 0,
          endAngle: 0
        };
        var i = d3.interpolate(start, finish);
        return function(d) { return arc(i(d)); };
      }

      var container = d3.select(elem)
        .select('svg')
        .append('g')
          .attr('class', 'container')
          .attr('transform', 'translate(' + (width + margin.left + margin.right) / 2 + ',' + ((height + margin.top + margin.bottom)-30) / 2 + ')');

      var g = container.selectAll('.arc')
          .data(pie(data))
        .enter().append('g')
          .attr('class', 'arc');

      if(hover) {
        var tooltipEl = elem+'-tooltip';

        var tooltip = d3.select(elem)
          .insert('div', 'svg')
            .attr('id', elemAttr+'-tooltip')
            .attr('class', 'tooltip-graph')

        var tooltipW = $(tooltipEl).width();
        var tooltipH = $(tooltipEl).height();

        tooltip.append('div')
          .attr('class', 'content');
        tooltip.append('div')
          .attr('class', 'bottom');

        var tooltipContent = d3.select(tooltipEl)
          .select('.content');

        tooltipContent.append('div')
          .attr('class', 'title');
        tooltipContent.append('div')
          .attr('class', 'value number');

        g.on('mousemove', function (d) {
          var cords = d3.mouse(this);
          d3.select(tooltipEl)
            .style('left', ( cords[0] + tooltipW + (tooltipW/2) + margin.left) + 'px')
            .style('top', ( cords[1] + tooltipH - (tooltipH/3) ) + 'px')
            .style('display', 'block');

          d3.select(tooltipEl)
            .select('.title')
            .text(d.data.name);

          d3.select(tooltipEl)
            .select('.value')
            .text(d.value.toFixed(decimals) + unit);
        });

        container.on('mouseout', function () {
            d3.select(tooltipEl)
              .style('display', 'none');
        });
      }

      g.append('path')
        .attr('d', arc)
        .style('fill', function(d) { return d.data.color; })
        .style('stroke', function(d) { return d.data.color; })
        .transition()
        .duration(duration)
        .attrTween('d', tweenPie)
        .style(function(d, i) {
        });

      g.append('text')
       .attr('transform', function(d) {
          var c = arc.centroid(d),
              x = c[0],
              y = c[1],
              h = Math.sqrt(x*x + y*y);
          return 'translate(' + (x/h * radius+5) +  ',' +
             (y/h * radius) +  ')';
        })
        .attr('dy', '.35em')
        .attr('text-anchor', function(d) {
          return (d.endAngle + d.startAngle)/2 > Math.PI ?
              'end' : 'start';
        });

      if(loader) {
        $el.removeClass(loader);
      }
    },

    buildLegend: function(params) {
      var elem = params.elem;
      var contentWidth = params.contentWidth;
      var contentHeight = params.contentHeight;
      var data = params.data;
      var unit = params.unit || '';
      var decimals = params.decimals || 0;

      var width = contentWidth,
          height = contentHeight;
      var legendRectSize = 5;
      var legendSpacingH = 9;
      var legendSpacingV = 14;
      var topMargin = 1;

      var svg = d3.select(elem).append('svg')
          .attr('width', width)
          .attr('height', height);

      var legend = svg.selectAll('.legend')
        .data(data)
        .enter()
        .append('g')
        .attr('class', 'legend')
        .attr('transform', function(d, i) {
          var heightRow = legendRectSize + legendSpacingV;
          var vert = i * heightRow + topMargin;
          return 'translate(0,' + vert + ')';
        });

      legend.append('circle')
        .attr('class', 'icon')
        .attr('cx', legendRectSize)
        .attr('cy', legendRectSize-1.3)
        .attr('r', legendRectSize)
        .style('fill', function(d){ return d.color; });

      legend.append('text')
        .attr('class', 'text')
        .attr('x', legendRectSize + legendSpacingH)
        .attr('y', legendRectSize + (legendSpacingV / legendRectSize) - topMargin)
        .text(function(d) { return d.name + ' ('+ d.value.toFixed(decimals) + unit +')'; });

    },

    buildLineChart: function(params) {
      var elem = params.elem;
      var elemAttr = elem.replace(/[#]|[.]/g, '');
      var $el = $(elem);
      var contentWidth = $el.width();
      var contentHeight = $el.height();
      var data = params.data;
      var hover = params.hover;
      var interpolate = params.interpolate || 'linear';
      var loader = params.loader || null;
      var infoWindow = params.infoWindowText || '';
      var decimals = params.decimals || 0;

      $el.addClass('graph-line');

      var width = contentWidth,
          height = contentHeight;

      var parseDate = d3.time.format('%d-%b-%Y').parse;
      var bisectDate = d3.bisector(function(d) { return d.date; }).left;

      var margin = {
        top: 10,
        right: 30,
        bottom: 40,
        left: 30,
        xaxis: 10,
        tooltip: 1.8
      };

      var width = width - margin.left - margin.right,
          height = height - margin.top - margin.bottom;

      var x = d3.time.scale()
          .range([0, width]);

      var y = d3.scale.linear()
          .range([height, 0]);

      var xAxis = d3.svg.axis()
          .scale(x)
          .orient('bottom')
          .ticks(5)
          .tickSize(0)
          .tickPadding(10)
          .tickFormat(d3.time.format('%Y'));

      var yAxis = d3.svg.axis()
          .scale(y)
          .orient('left')
          .ticks(7)
          .innerTickSize(-width)
          .outerTickSize(0)
          .tickPadding(4)
          .tickFormat('');

      var line = d3.svg.line()
          .x(function(d) { return x(d.date); })
          .y(function(d) { return y(d.value); })
          .interpolate(interpolate);

      var svg = d3.select(elem).append('svg')
        .attr('width', width + margin.left + margin.right)
        .attr('height', height + margin.top + margin.bottom)
        .append('g')
          .attr('transform', 'translate('+margin.left+',' + margin.top + ')');

      data.forEach(function(d) {
        d.date = parseDate(d.date);
      });

      x.domain(d3.extent(data, function(d) { return d.date; })).nice();
      y.domain(d3.extent(data, function(d) { return d.value ; })).nice();

      svg.append('g')
        .attr('class', 'x axis')
        .attr('transform', 'translate(0,' + (height + margin.xaxis) + ')')
        .call(xAxis);

      svg.append('g')
        .attr('class', 'y axis')
        .call(yAxis)

      svg.append('path')
          .datum(data)
          .attr('class', 'line')
          .attr('d', line);

      function mousemove() {
        var x0 = x.invert(d3.mouse(this)[0]),
            i = bisectDate(data, x0, 1),
            d0 = data[i - 1],
            d1 = data[i];

        if(d0 && d0.date && d1 && d1.date) {
          var d = x0 - d0.date > d1.date - x0 ? d1 : d0;
          focus.attr('transform', 'translate(' + x(d.date) + ',' + y(d.value) + ')');

          // Move trail
          trail.attr('transform', 'translate(' + x(d.date) + ', '+y(d.value)+')');
          trailLine.attr('y2', height - y(d.value));

          // Update tooltip
          d3.select(tooltipEl)
            .style('left', ( (x(d.date) + margin.left) + (radius/2) - margin.tooltip - (tooltipW / 2) ) + 'px')
            .style('top', ( (y(d.value) + margin.top) - (tooltipH + (tooltipH/3)) + (radius / 2) - margin.tooltip ) + 'px')
            .style('display', 'block');

          d3.select(tooltipEl)
            .select('.title')
            .text(infoWindow + ' ' + new Date(d.date).getFullYear());

          d3.select(tooltipEl)
            .select('.value')
            .text(d.value);
        }
      }

      if(hover) {
        /** Tooltip **/
        var tooltipEl = elem+'-tooltip';
        var tooltip = d3.select(elem)
          .insert('div', 'svg')
            .attr('id', elemAttr+'-tooltip')
            .attr('class', 'tooltip-graph')

        var tooltipW = $(tooltipEl).width();
        var tooltipH = $(tooltipEl).height();

        tooltip.append('div')
          .attr('class', 'content');
        tooltip.append('div')
          .attr('class', 'bottom');

        var tooltipContent = d3.select(tooltipEl)
          .select('.content');

        tooltipContent.append('div')
          .attr('class', 'title')
          .text(infoWindow);
        tooltipContent.append('div')
          .attr('class', 'value number');

        /** Trail **/
        var trail = svg.append('g');
        var trailLine = trail.append('line')
          .attr('class', 'trail')
          .style('display', 'none')
          .attr('x1', 0)
          .attr('y1', 0)
          .attr('x2', 0)
          .attr('y2', 50);

        var radius = 4;
        var focus = svg.append('g')
          .attr('class', 'focus')
          .style('display', 'none');

        focus.append('circle')
          .attr('r', radius);

        svg.append('rect')
          .attr('class', 'overlay')
          .attr('width', width)
          .attr('height', height)
          .on('mouseover', function() {
            focus.style('display', null);
            trailLine.style('display', null);
            d3.select(tooltipEl)
              .style('display', 'block');
          })
          .on('mouseout', function() {
            focus.style('display', 'none');
            trailLine.style('display', 'none');
            d3.select(tooltipEl)
              .style('display', 'none');
          })
          .on('mousemove', mousemove);
      }

      if(loader) {
        $el.removeClass(loader);
      }
    },

    buildBarsChart: function(params) {
      var elem = params.elem;
      var elemAttr = elem.replace(/[#]|[.]/g, '');
      var $el = $(elem);
      var contentWidth = $el.width();
      var contentHeight = $el.height();
      var data = params.data;
      var hover = params.hover;
      var loader = params.loader || null;
      var infoWindow = params.infoWindowText || '';
      var decimals = params.decimals || 0;
      var unit = params.unit || ''; 
      var barWidth = params.barWidth || 10;
      var barSeparation = params.barSeparation || 10;
      var xIsDate = params.xIsDate || false;
      var hasLine = params.hasLine || false;
      var interpolate = params.interpolate || 'linear';
      var transition = 200;

      $el.addClass('graph-line');

      var width = contentWidth,
          height = contentHeight;

      var parseDate = d3.time.format('%d-%b-%Y').parse;
      var yearFormat = d3.time.format('%Y');

      var margin = {
        top: 10,
        right: 0,
        bottom: 20,
        left: 0,
        xaxis: 10,
        tooltip: 1.8
      };

      var width = width - margin.left - margin.right,
          height = height - margin.top - margin.bottom;
      var heightPadding = height - 50;

      var totalBarsWidth = ((barWidth + barSeparation) * data.length) - barSeparation;
      var centerContainer = (contentWidth / 2) - (totalBarsWidth / 2);

      if(xIsDate) {
        data.forEach(function(d) {
          d.date = parseDate(d.date);
        });
      }

      if(hasLine) {
        var line = d3.svg.line()
          .x(function(d, i) { 
            return (barWidth+barSeparation) * i;
          })
          .y(function(d) { return y(d.z); })
          .interpolate(interpolate);
      }

      var svgBars = d3.select(elem).append('svg')
        .attr('class', '')
        .attr('width', width + margin.left + margin.right)
        .attr('height', height + margin.top + margin.bottom)
        .append('g')
        .attr('transform', 'translate(0,0)');

      var y = d3.scale.linear()
        .range([height, 0]);

      y.domain([0, d3.max(data, function(d) { return d.value; })]);

      var yScale = d3.scale.linear()
       .domain([0, d3.max(data, function(d) { return d.value; })])
       .range([heightPadding, 0]);

      var yAxis = d3.svg.axis()
          .scale(y)
          .orient('left')
          .ticks(4)
          .innerTickSize(-width)
          .outerTickSize(0)
          .tickPadding(4)
          .tickFormat('');

      svgBars.append('g')
        .attr('class', 'y axis')
        .call(yAxis)

      var barsContent = d3.select(elem+' svg').append('g')
        .attr('transform', 'translate('+ centerContainer +', 1)');

      var barGroup = barsContent.selectAll('g')
        .data(data)
        .enter().append('g')
        .attr('transform', function(d,i) {
          return 'translate(' + ((barWidth+barSeparation) * i) + ', 25)';
        });

      barGroup.append('rect')
        .style('fill', function(d) { return d.color; })
        .attr('class', 'progress-rects')
        .attr('width', barWidth)
        .attr('height', function() {
          return 0;
        })
        .attr('y', function () {
          return heightPadding + 25;
        })
        .transition().duration(transition).ease('linear')
        .delay(transition * 2)
        .attr('height', function(d) {
          return heightPadding - yScale(d.value);
        })
        .attr('y', function (d) { return  yScale(d.value) + 25; });

      if(hasLine) {
        barsContent.append('g')
        .attr('transform', function(d,i) {
          return 'translate(' + ((barWidth) / 2) + ', 25)';
        }).append('path')
          .datum(data)
          .attr('class', 'line')
          .attr('d', line); 
      }

      d3.select(elem+' svg').append('g')
        .attr('transform', 'translate('+ centerContainer +', '+ height +')')
        .attr('class', 'x axis')
        .selectAll('text.bar')
        .data(data)
        .enter().append('text')
          .attr('class', 'bar-text')
          .attr('x', function(d, i) {
              return (barWidth+barSeparation) * i + 2;
           })
          .attr('y', function(d) { return 15 })
          .text(function(d) { 
            if(xIsDate) {
              return yearFormat(d.date); 
            } else {
              return d.x;
            }
          });
      
      if(loader) {
        $el.removeClass(loader);
      }

      if(hover) {
        var tooltipEl = elem+'-tooltip';

        var tooltip = d3.select(elem)
          .insert('div', 'svg')
            .attr('id', elemAttr+'-tooltip')
            .attr('class', 'tooltip-graph')

        var tooltipW = $(tooltipEl).width();
        var tooltipH = $(tooltipEl).height();

        tooltip.append('div')
          .attr('class', 'content');
        tooltip.append('div')
          .attr('class', 'bottom');

        var tooltipContent = d3.select(tooltipEl)
          .select('.content');

        tooltipContent.append('div')
          .attr('class', 'title');
        tooltipContent.append('div')
          .attr('class', 'value number');

        barGroup.on('mousemove', function (d) {
          var element = d3.select(elem+' svg');
          var cords = d3.mouse(element.node());

          d3.select(tooltipEl)
            .style('left', ( cords[0] - (tooltipW / 2)) + 'px')
            .style('top', ( cords[1] - tooltipH - (tooltipH/3) ) + 'px')
            .style('display', 'block');

          d3.select(tooltipEl)
            .select('.title')
            .text(d.name);

          d3.select(tooltipEl)
            .select('.value')
            .text(d.value.toFixed(decimals) + unit);
        });

        barGroup.on('mouseout', function () {
            d3.select(tooltipEl)
              .style('display', 'none');
        });
      }
    },

    buildBarsHorizontalChart: function(params) {

      var elem = params.elem;
      var elemAttr = elem.replace(/[#]|[.]/g, '');
      var $el = $(elem);
      var contentWidth = $el.width();
      var data = params.data;
      var hover = params.hover;
      var loader = params.loader || null;
      var infoWindow = params.infoWindowText || '';
      var decimals = params.decimals || 0;
      var unit = params.unit || ''; 
      var barHeight = params.barHeight || 10;
      var barSeparation = params.barSeparation || 10;
      var transition = 200;
      var yAxisWidth = 275;

      // $el.addClass('graph-line');

      var width = contentWidth;
      var margin = {
        top: 20,
        right: 0,
        bottom: 10,
        left: 0,
        xaxis: 10,
        tooltip: 1.8
      };

      var totalBarsHeight = ((barHeight + barSeparation) * data.length) + 
        barSeparation + margin.bottom;
      var width = width - margin.left - margin.right,
          height = totalBarsHeight - margin.top - margin.bottom;
      var widthPadding = width - yAxisWidth - 150;  

      var svgBars = d3.select(elem).append('svg')
        .attr('class', '')
        .attr('width', width + margin.left + margin.right)
        .attr('height', height + margin.top + margin.bottom)
        .append('g')
        .attr('transform', 'translate(0, 0)');

      var x = d3.scale.linear()
        .range([width, 0]);

      x.domain([0, d3.max(data, function(d) { return d.value; })]);

      var xScale = d3.scale.linear()
       .domain([0, d3.max(data, function(d) { return d.value; })])
       .range([widthPadding, 0]);

      var yScale = d3.scale.linear()
        .domain([0, data.length])
        .range([0, height]);

      var yAxis = d3.svg.axis()
        .orient('left')
        .scale(yScale)
        .ticks(data.length)
        .tickFormat(function(d,i){ 
          if(data[i]) {
            return data[i].name;
          }
        });

      svgBars.append('g')
        .attr('class', 'y axis')
        .attr('transform', 'translate('+ yAxisWidth +', 17)')
        .call(yAxis);

      d3.selectAll(elem+' .tick')
        .attr('transform', function(d,i) {
          return 'translate(0, ' + ((barHeight+barSeparation) * i) + ')';
        });

      d3.select(elem+' svg')
        .append('g')
        .attr('transform', 'translate('+ yAxisWidth + ',0)')
        .attr('class', 'yDomain')
        .append('line')
          .attr('class', 'domainAxis')
          .attr('width', '1')
          .attr('x1', 0)
          .attr('y1', 0)
          .attr('x2', 0)
          .attr('y2', totalBarsHeight);

      var barsContent = d3.select(elem+' svg').append('g')
        .attr('transform', 'translate('+ yAxisWidth +', '+ ((barHeight+barSeparation) / 2) +')');

      var barGroup = barsContent.selectAll('g')
        .data(data)
        .enter().append('g')
        .attr('transform', function(d,i) {
          // return 'translate(0, ' + ((barHeight+barSeparation) * i) + ')';
          return 'translate(0, ' + ((barHeight + barSeparation) * i) + ')';
        });

      barGroup.append('rect')
        .style('fill', function(d) { return d.color; })
        .attr('class', 'progress-rects')
        .attr('height', barHeight)
        .attr('width', function() {
          return 0;
        })
        .attr('y', function () {
          return 0;
        })
        .transition().duration(transition).ease('linear')
        .attr('width', function(d) {
          return widthPadding - xScale(d.value);
        })
        .attr('y', function (d, i) { return 0 });

      barGroup.append('rect')
        .attr('fill', 'transparent')
        .attr('width', function(d) {
          return widthPadding - xScale(d.value);
        })
        .attr('height', barSeparation)
        .attr('y', function(d, i) { return barHeight });

      barGroup.append('text')
        .attr('x', function(d) { return widthPadding - xScale(d.value) + barSeparation })
        .attr('y', '11')
        .attr('class', 'bar-text')
        .text(function(d) { return d.value.toFixed(decimals) + unit });

      if(loader) {
        $el.removeClass(loader);
      }

      if(hover) {
        var tooltipEl = elem+'-tooltip';

        var tooltip = d3.select(elem)
          .insert('div', 'svg')
            .attr('id', elemAttr+'-tooltip')
            .attr('class', 'tooltip-graph left')

        var tooltipW = $(tooltipEl).width();
        var tooltipH = $(tooltipEl).height();

        tooltip.append('div')
          .attr('class', 'content');
        tooltip.append('div')
          .attr('class', 'bottom');

        var tooltipContent = d3.select(tooltipEl)
          .select('.content');

        tooltipContent.append('div')
          .attr('class', 'title');
        tooltipContent.append('div')
          .attr('class', 'value number');

        barGroup.on('mousemove', function (d) {
          var element = d3.select(elem+' svg');
          var cords = d3.mouse(element.node());

          d3.select(tooltipEl)
            .style('left', cords[0] + 35 + 'px')
            .style('top', ( cords[1] - (tooltipH / 2) ) + 'px')
            .style('display', 'block');

          d3.select(tooltipEl)
            .select('.title')
            .text(d.name);

          d3.select(tooltipEl)
            .select('.value')
            .text(d.value.toFixed(decimals) + unit);
        });

        barGroup.on('mouseout', function () {
          d3.select(tooltipEl)
            .style('display', 'none');
        });
      }
    },

    // STACKED

    buildBarsHorizontalStackedChart: function(params) {
      var elem = params.elem;
      var elemAttr = elem.replace(/[#]|[.]/g, '');
      var $el = $(elem);
      var contentWidth = $el.width();
      var data = params.data;
      var hover = params.hover;
      var loader = params.loader || null;
      var infoWindow = params.infoWindowText || '';
      var decimals = params.decimals || 0;
      var unit = params.unit || ''; 
      var barHeight = params.barHeight || 10;
      var barSeparation = params.barSeparation || 10;
      var transition = 200;
      var yAxisWidth = 275;
      var bucket = params.bucket;

      var width = contentWidth;
      var margin = {
        top: 20,
        right: 0,
        bottom: 10,
        left: 0,
        xaxis: 10,
        tooltip: 1.8
      };

      var totalBarsHeight = ((barHeight + barSeparation) * data.length) + 
        barSeparation + margin.bottom;
      var width = width - margin.left - margin.right,
          height = totalBarsHeight - margin.top - margin.bottom;
      var widthPadding = width - yAxisWidth - 150;  

      var indicators = data[0].data.length;
      var groups = data.length;
      var stack = d3.layout.stack();
      var ticks = data.map(function(d) { return d.name; });
    
      data = stack(d3.range(indicators).map(function(d) { 
        var a = [];
        for (var i = 0; i < groups; ++i) {
          var item = data[i].data[d];
          a[i] = {
            x: i, 
            y: item.y, 
            value: item.value, 
            name: item.name, 
            key_name: item.key_name
          };  
        }
        return a;
      }));

      var yGroupMax = d3.max(data, function(layer) { 
        return d3.max(layer, function(d) { 
          return d.y; 
        }); 
      });

      var yStackMax = d3.max(data, function(layer) { 
        var max =d3.max(layer, function(d) { 
          return d.y0 + d.y; 
        });
        return max;
      });

      var y = d3.scale.ordinal()
        .domain(d3.range(groups))
        .rangeRoundBands([2, height], .08);

      var x = d3.scale.linear()
        .domain([0, yStackMax])
        .range([0, widthPadding]);

      var yScale = d3.scale.ordinal()
        .domain(ticks)
        .rangeRoundBands([0, height], .1);

      var yAxis = d3.svg.axis()
        .orient('left')
        .scale(yScale)
        .ticks(ticks.length)
        .tickFormat(function(d){ 
          return d;
        });

      var svgBars = d3.select(elem).append('svg')
        .attr('class', '')
        .attr('width', width + margin.left + margin.right)
        .attr('height', height + margin.top + margin.bottom)
        .append('g')
        .attr('transform', 'translate(0, 0)');

      svgBars.append('g')
        .attr('class', 'y axis')
        .attr('transform', 'translate('+ yAxisWidth +', 17)')
        .call(yAxis);

      d3.selectAll(elem+' .tick')
        .attr('transform', function(d,i) {
          return 'translate(0, ' + ((barHeight+barSeparation) * i) + ')';
        });

      d3.select(elem+' svg')
        .append('g')
        .attr('transform', 'translate('+ yAxisWidth + ',0)')
        .attr('class', 'yDomain')
        .append('line')
          .attr('class', 'domainAxis')
          .attr('width', '1')
          .attr('x1', 0)
          .attr('y1', 0)
          .attr('x2', 0)
          .attr('y2', totalBarsHeight);

      var barsContent = d3.select(elem+' svg').append('g')
        .attr('transform', 'translate('+ yAxisWidth +', '+ ((barHeight+barSeparation) / 2) +')');

      var layer = barsContent.selectAll(".layer")
          .data(data)
        .enter().append("g")
          .attr("class", "layer")
          .style("fill", function(d, i) { return bucket[i]; });

      layer.selectAll("rect")
        .data(function(d) { return d; })
        .enter().append("rect")
        .attr("y", function(d, i) { return y(d.x) + ((y(i) / 10) - 6); })
        .attr("x", function(d) { return x(d.y0); })
        .attr("height", barHeight)
        .attr("width", function(d) { return x(d.y); });


      if(loader) {
        $el.removeClass(loader);
      }

      if(hover) {
        var tooltipEl = elem+'-tooltip';

        var tooltip = d3.select(elem)
          .insert('div', 'svg')
            .attr('id', elemAttr+'-tooltip')
            .attr('class', 'tooltip-graph left');

        var tooltipW = $(tooltipEl).width();
        var tooltipH = $(tooltipEl).height();

        tooltip.append('div')
          .attr('class', 'content');
        tooltip.append('div')
          .attr('class', 'bottom');

        var tooltipContent = d3.select(tooltipEl)
          .select('.content');

        tooltipContent.append('div')
          .attr('class', 'title');
        tooltipContent.append('div')
          .attr('class', 'value number');

        layer.on('mousemove', function (d, i, k) {
          var item = d[i];
          var element = d3.select(elem+' svg');
          var cords = d3.mouse(element.node());

          d3.select(tooltipEl)
            .style('left', cords[0] + 35 + 'px')
            .style('top', ( cords[1] - (tooltipH / 2) ) + 'px')
            .style('display', 'block');

          d3.select(tooltipEl)
            .select('.title')
            .text(function(){
              if(item && item.key_name) {
                return item.key_name;
              }
            });

          d3.select(tooltipEl)
            .select('.value')
            .text(function() {
              if(item) {
                return item.y.toFixed(decimals) + unit;
              }
            });
        });

        layer.on('mouseout', function () {
          d3.select(tooltipEl)
            .style('display', 'none');
        });
      }

      // Legend

      var categories = [];

      _.each(data, function(cat) {
        var item = _.first(cat);
        categories.push(item.key_name);
      });

      var legendEl = elem+'-legend';

      var legend = d3.select(elem)
        .append('div', 'svg')
          .attr('id', elemAttr+'-legend')
          .attr('class', 'legend-stack-graph left')
          .append('ul')
            .attr('class', 'list');

      var items = legend.selectAll('li.item')
        .data(categories);

      items.enter().append('li')
        .attr('class', 'item')
        .style('border-top-color', String)
        .append('span')
        .text(function(d) {
          return d;
        });

      legend.selectAll('li.item')
        .insert('div', 'span')
        .attr('class', 'list-icon')
        .style('background-color', function(d, i) {
          return bucket[i];
        });
    },
  });

})(this);