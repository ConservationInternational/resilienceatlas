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
      var isCircle = params.isCircle || false;

      var width = contentWidth,
          height = contentHeight;
      var legendRectSize = 10;
      var legendCircleSize = 5;
      var legendSpacingH = 15;
      var legendSpacingV = 16;
      var topMargin = -3;

      var svg = d3.select(elem).append('svg')
          .attr('width', width)
          .attr('height', (legendRectSize + legendSpacingV) * data.length);

      var legend = svg.selectAll('.legend-content')
        .data(data)
        .enter()
        .append('g')
        .attr('class', 'legend-content')
        .attr('transform', function(d, i) {
          var heightRow = legendRectSize + legendSpacingV;
          var vert = i * heightRow + topMargin;
          return 'translate(0,' + vert + ')';
        });

      if(isCircle) {
        legend.append('g')
          .attr('transform', 'translate('+ legendRectSize +', '+ legendRectSize +')')
          .append('circle')
            .attr('r', legendCircleSize)
            .style('fill', function(d){ return d.color; });
      } else {
        legend.append('rect')
          .attr('x', legendRectSize)
          .attr('y', (legendRectSize/2)-1.3)
          .attr('width', legendRectSize + "px")
          .attr('height', legendRectSize + "px")
          .style('fill', function(d){ return d.color; });
      }

      legend.append('text')
        .attr('class', 'text')
        .attr('x', legendRectSize + legendSpacingH)
        .attr('y', legendRectSize + (legendSpacingV / legendRectSize) - topMargin)
        .text(function(d) { return d.name; });

    },

    buildLineChart: function(params) {
      var elem = params.elem;
      var elemAttr = elem.replace(/[#]|[.]/g, '');
      var $el = $(elem);
      var contentWidth = $el.width();
      var contentHeight = $el.height();
      var data = params.data;
      var dateFormat = params.dateFormat || '%Y';
      var hover = params.hover;
      var interpolate = params.interpolate || 'linear';
      var loader = params.loader || null;
      var infoWindow = params.infoWindowText || '';
      var decimals = params.decimals || 0;
      var unit = params.unit || '';
      var margin = params.margin || {
        top: 30,
        right: 0,
        bottom: 40,
        left: 0,
        xaxis: 10,
        tooltip: 1.8
      };

      $el.addClass('graph-line');

      var width = contentWidth,
          height = contentHeight;

      var parseDate = d3.time.format('%d-%b-%Y').parse;
      var bisectDate = d3.bisector(function(d) { return d.date; }).left;

      var width = width - margin.left - margin.right,
          height = height - margin.top - margin.bottom;

      var x = d3.time.scale()
          .range([0, width]);

      var y = d3.scale.linear()
          .range([height, 0]);

      var xAxis = d3.svg.axis()
          .scale(x)
          .orient('bottom')
          .tickSize(0)
          .tickPadding(10)
          .tickFormat(d3.time.format(dateFormat));

      var yAxis = d3.svg.axis()
          .scale(y)
          .orient('left')
          .ticks(7)
          .innerTickSize(-width)
          .outerTickSize(0)
          .tickPadding(4);
          // .tickFormat('');

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
        .attr('class', 'y axis')
        .call(yAxis);

      svg.append('g')
        .attr('class', 'x axis')
        .attr('transform', 'translate(0,' + (height) + ')')
        .call(xAxis);

      svg.append('path')
          .datum(data)
          .attr('class', 'line')
          .attr('d', line);

      svg.append('g')
          .attr('transform', 'translate(-5, -10)').append('text')
          .attr('class', 'unit')
          .attr('x', function(d) { return 0 })
          .attr('y', '-10')
          .attr('dy', '.35em')
          .attr('text-anchor', 'start')
          .text(function(d) { return unit; });

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
          trailLine.attr('y2', (height) - y(d.value));

          // Update tooltip
          d3.select(tooltipEl)
            .style('left', ( (x(d.date) + margin.left) + (radius/2) - margin.tooltip - (tooltipW / 2) ) + 'px')
            .style('top', ( (y(d.value) + margin.top) - (tooltipH + (tooltipH/3)) + (radius / 2) - margin.tooltip ) + 'px')
            .style('display', 'block');

          d3.select(tooltipEl)
            .select('.title')
            .text(infoWindow + ' ' + d.x);

          d3.select(tooltipEl)
            .select('.value')
            .text(d.value).append('span')
            .attr('class', 'tooltip-unit')
            .text(unit);
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

    buildMultiLineChart: function(params) {
      var dataKeys = params.dataKeys;
      var elem = params.elem;
      var elemAttr = elem.replace(/[#]|[.]/g, '');
      var $el = $(elem);
      var contentWidth = $el.width();
      var contentHeight = $el.height();
      var data = params.data;
      var dateFormat = params.dateFormat || '%b %Y';
      // var hover = params.hover;
      var hover = false;
      var interpolate = params.interpolate || 'linear';
      var loader = params.loader || null;
      var infoWindow = params.infoWindowText || '';
      var decimals = params.decimals || 0;
      var unit = params.unit || '';
      var bucket = params.bucket;
      var margin = params.margin || {
        top: 30,
        right: 0,
        bottom: 40,
        left: 0,
        xaxis: 10,
        tooltip: 1.8
      };

      $el.addClass('graph-multiline');

      var width = contentWidth,
          height = contentHeight;

      var parseDate = d3.time.format("%b %Y").parse;
      var bisectDate = d3.bisector(function(d) { return d.year; }).left;

      var width = width - margin.left - margin.right,
          height = height - margin.top - margin.bottom;

      var x = d3.time.scale().range([0, width]);
      var y = d3.scale.linear().range([height, 0]);

      var xAxis = d3.svg.axis()
          .scale(x)
          .orient('bottom')
          .tickSize(0)
          .tickPadding(10)
          .tickFormat(d3.time.format('%Y'));

      var yAxis = d3.svg.axis()
          .scale(y)
          .orient('left')
          .ticks(7)
          .innerTickSize(-width)
          .outerTickSize(0)
          .tickPadding(4);
          // .tickFormat('');

      var line = d3.svg.line()
          .x(function(d) { return x(d.year); })
          .y(function(d) { return y(d.value); })
          .defined(function(d) { return d.value; })
          .interpolate(interpolate);

      var svg = d3.select(elem).append('svg')
        .attr('width', width + margin.left + margin.right)
        .attr('height', height + margin.top + margin.bottom)
        .append('g')
          .attr('transform', 'translate('+margin.left+',' + margin.top + ')');


      data.forEach(function(d) {
        d.year = parseDate(d.year);
        d.value = d.value;
      });

      x.domain(d3.extent(data, function(d) { return d.year; }));
      y.domain([0, d3.max(data, function(d) { return d.value; })]); 

      // Nest the entries by symbol
      var dataNest = d3.nest()
          .key(function(d) { return d.symbol; })
          .entries(data);

      svg.append('g')
        .attr('class', 'y axis')
        .call(yAxis);

      svg.append('g')
        .attr('class', 'x axis')
        .attr('transform', 'translate(0,' + (height) + ')')
        .call(xAxis);

      // Loop through each symbol / key
      dataNest.forEach(function(d, i) {
          svg.append("path")
              .attr("class", "multiline")
              .attr("d", line(d.values))
              .attr('stroke', function() { return bucket[i]; })
      });

      svg.append('g')
          .attr('transform', 'translate(-5, -10)').append('text')
          .attr('class', 'unit')
          .attr('x', function(d) { return 0 })
          .attr('y', '-10')
          .attr('dy', '.35em')
          .attr('text-anchor', 'start')
          .text(function(d) { return unit; });

      function mousemove() {
        var x0 = x.invert(d3.mouse(this)[0]),
            i = bisectDate(data, x0, 1),
            d0 = data[i - 1],
            d1 = data[i];

        if(d0 && d0.year && d1 && d1.year) {
          var d = x0 - d0.year > d1.year - x0 ? d1 : d0;
          focus.attr('transform', 'translate(' + x(d.year) + ',' + y(d.value) + ')');

          // Move trail
          trail.attr('transform', 'translate(' + x(d.year) + ', '+y(d.value)+')');
          trailLine.attr('y2', (height) - y(d.value));

          // Update tooltip
          d3.select(tooltipEl)
            .style('left', ( (x(d.year) + margin.left) + (radius/2) - margin.tooltip - (tooltipW / 2) ) + 'px')
            .style('top', ( (y(d.value) + margin.top) - (tooltipH + (tooltipH/3)) + (radius / 2) - margin.tooltip ) + 'px')
            .style('display', 'block');

          d3.select(tooltipEl)
            .select('.title')
            .text(infoWindow + ' ' + d.x);

          d3.select(tooltipEl)
            .select('.value')
            .text(d.value).append('span')
            .attr('class', 'tooltip-unit')
            .text(unit);
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
      var unitZ = params.unitZ || ''; 
      var barWidth = params.barWidth || 10;
      var barSeparation = params.barSeparation || 10;
      var xIsDate = params.xIsDate || false;
      var hasLine = params.hasLine || false;
      var interpolate = params.interpolate || 'linear';
      var transition = 200;
      var margin = params.margin || {
        top: 30,
        right: 65,
        bottom: 30,
        left: 30,
        xaxis: 10,
        tooltip: 1.8
      };

      $el.addClass('graph-line');

      var width = contentWidth,
          height = contentHeight;

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
          .attr('transform', 'translate('+(margin.left * 2)+', '+ margin.top +')');

      var x = d3.scale.ordinal()
        .rangeRoundBands([0, width], .4);

      var x2 = d3.scale.ordinal()
        .rangeBands([0, width], 0);

      x.domain(data.map(function(d) { return d.x; }));
      x2.domain(data.map(function(d) { return d.x; }));

      var yMin = d3.min(data,function(d){ return d.y; });
      var yMax = d3.max(data, function(d) { return d.y; });

      if (hasLine) { 
        var zMin = d3.min(data,function(d){ return d.z; });
        var zMax = d3.max(data, function(d) { return d.z; });

        if (zMin < yMin) {
          yMin = zMin;
        }

        if (zMax > yMax) {
          yMax = zMax;
        }
      }

      // if(yMin >= 0) {
      //   yMin = 0;
      // }

      if(hasLine) {
        var zMax = d3.max(data, function(d) { return d.z; });
        var z = d3.scale.linear()
          .domain([yMin, zMax])
          .range([height,0]).nice();
      }

      var y = d3.scale.linear()
        .domain([yMin, yMax])
        .range([height,yMin]).nice();

      var xAxis = d3.svg.axis()
        .scale(x)
        .orient('bottom')
        .ticks(5)
        .tickSize(0)
        .tickPadding(10);

      var yAxis = d3.svg.axis()
        .scale(y)
        .orient('left')
        .ticks(4)
        .innerTickSize(-width)
        .outerTickSize(0)
        .tickPadding(4)
        .ticks(8);

      var zAxis = d3.svg.axis()
        .scale(z)
        .orient('right')
        .ticks(4)
        .innerTickSize(-width)
        .outerTickSize(0)
        .tickPadding(4)
        .ticks(8);

     var line = d3.svg.line()
       .x(function(d, i) { 
         return x2(d.x) + i; })
       .y(function(d) { return z(d.z); })
       .interpolate(interpolate);

      svgBars.append("g")
          .attr("class", "y axis")
          .call(yAxis);

      if(hasLine) {
        svgBars.append("g")
          .attr("class", "y z axis")
          .attr('transform', 'translate('+ width +', 0)')
          .call(zAxis);
      }

      svgBars.append("g")
          .attr("class", "x axis")
          .attr("transform", "translate(0," + height + ")")
          .call(xAxis);

      svgBars.selectAll(".bar")
          .data(data)
        .enter().append("rect")
          .attr("class", "bar")
          .style('fill', function(d) { return d.color; })
          .attr("x", function(d) { return x(d.x); })
          .attr("width", x.rangeBand()) 
          .attr("y", function(d) { return y(Math.max(0, d.y)); })
          .attr("height", function(d) { return yMin >= 0 ? Math.abs(height - y(d.y)) : Math.abs(y(d.y) - y(0)); })
          
      svgBars.append("g")
          .attr("class", "y axis")
        .append("line")
          .attr("y1", yMin >= 0 ? height : y(0))
          .attr("y2", yMin >= 0 ? height : y(0))
          .attr("x1", 0)
          .attr("x2", width);

      svgBars.append('g')
          .attr('transform', 'translate(-5, -10)').append('text')
          .attr('class', 'unit')
          .attr('x', function(d) { return 0 })
          .attr('y', '-10')
          .attr('dy', '.35em')
          .attr('text-anchor', 'start')
          .text(function(d) { return unit; });
      
      if(hasLine) {

        svgBars.append('g')
          .attr('transform', 'translate('+ (width + (margin.left / 2)) +', -10)').append('text')
          .attr('class', 'unit z')
          .attr('x', function(d) { return 0 })
          .attr('y', '-10')
          .attr('dy', '.35em')
          .attr('text-anchor', 'start')
          .text(function(d) { return unitZ; });

        svgBars.append('g')
          .attr('transform', function(d,i) {
            return 'translate(' + ((barWidth) / 2) + ', 0)';
          }).append('path')
            .datum(data)
            .attr('class', 'line')
            .attr('stroke', function(d) { return d.lineColor })
            .attr('d', line); 
      }

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

        d3.selectAll(elem+' .bar').on('mousemove', function (d) {
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
            .text(d.value).append('span')
            .attr('class', 'tooltip-unit')
            .text(unit);
        });

        d3.selectAll(elem+' .bar').on('mouseout', function () {
            d3.select(tooltipEl)
              .style('display', 'none');
        });
      }
    },

    buildGroupBarsChart: function(params) {
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
      var bucket = params.bucket;
      var margin = params.margin || {
        top: 30,
        right: 0,
        bottom: 0,
        left: 0,
        xaxis: 10,
        tooltip: 1.8
      };

      $el.addClass('graph-line');

      var width = contentWidth,
          height = contentHeight;

      var parseDate = d3.time.format('%d-%b-%Y').parse;
      var yearFormat = d3.time.format('%Y');

      var width = width - margin.left - margin.right,
          height = height - margin.top - margin.bottom;
      var heightPadding = height - 50;

      var x0 = d3.scale.ordinal()
          .rangeRoundBands([0, width], .1);

      var x1 = d3.scale.ordinal();

      var y = d3.scale.linear()
          .range([height, 0]);

      var xAxis = d3.svg.axis()
          .scale(x0)
          .orient('bottom');

      var yAxis = d3.svg.axis()
          .scale(y)
          .orient('left');

      var svg = d3.select(elem).append('svg')
        .attr('class', '')
        .attr('width', width + margin.left + margin.right)
        .attr('height', height + (margin.top * 2) + margin.bottom)
        .append('g')
        .attr('transform', 'translate('+margin.left+', '+ margin.top +')');

        var labels = d3.keys(data[0]).filter(function(key) { return key !== 'x'; });

        data.forEach(function(d) {
          d.cats = labels.map(function(name) { return {name: name, value: +d[name]}; });
        });

        x0.domain(data.map(function(d) { return d.x; }));
        x1.domain(labels).rangeRoundBands([0, x0.rangeBand()]);
        y.domain([0, d3.max(data, function(d) { return d3.max(d.cats, function(d) { return d.value; }); })]);

        svg.append('g')
          .attr('class', 'x axis')
          .attr('transform', 'translate(0,' + (height) + ')')
          .call(xAxis);

        svg.append('g')
          .attr('class', 'y axis')
          .call(yAxis)
        .append('text')
          .attr('transform', 'rotate(-90)')
          .attr('y', 2)
          .attr('dy', '.71em')
          .style('text-anchor', 'end')
          .text('');

        var cats = svg.selectAll('.cats')
          .data(data)
        .enter().append('g')
          .attr('class', 'g')
          .attr('transform', function(d) { return 'translate(' + x0(d.x) + ',0)'; });

        cats.selectAll('rect')
          .data(function(d) { return d.cats; })
        .enter().append('rect')
          .attr('width', x1.rangeBand()-1)
          .attr('x', function(d) { return x1(d.name); })
          .attr('y', function(d) { return y(d.value); })
          .attr('height', function(d) { return height - y(d.value); })
          .style('fill', function(d, i) { return bucket[i]; });

      if(loader) {
        $el.removeClass(loader);
      }

    },

    buildGroupHorizontalBarsChart: function(params) {
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
      var interpolate = params.interpolate || 'linear';
      var transition = 200;
      var bucket = params.bucket;
      var margin = params.margin || {
        top: 30,
        right: 0,
        bottom: 0,
        left: 0,
        xaxis: 10,
        tooltip: 1.8
      };

      var width = contentWidth,
          height = contentHeight;

      var maxLabelCharNum = d3.max(data.labels, function(d) {
        return d.length;
      });

      var chartWidth       = width,
          barHeight        = 12,
          groupHeight      = barHeight * data.series.length,
          gapBetweenGroups = 10,
          charWidthForLabels = 15,
          spaceForLabels   = maxLabelCharNum * charWidthForLabels,
          maxSpaceForLabels = 100,
          spaceValueText   = 5,
          spaceForLegend   = 180;

      var zippedData = [];
      for (var i=0; i<data.labels.length; i++) {
        for (var j=0; j<data.series.length; j++) {
          zippedData.push(data.series[j].values[i]);
        }
      }

      var chartHeight = barHeight * zippedData.length + gapBetweenGroups * data.labels.length;
      var maxValue = d3.max(zippedData);

      if(maxValue.toString().length > 5) {
        chartWidth = chartWidth - 50;
      }

      if(spaceForLabels > maxSpaceForLabels) {
        spaceForLabels = maxSpaceForLabels;
      }

      var x = d3.scale.linear()
          .domain([0, maxValue])
          .range([0, chartWidth-spaceForLabels-spaceValueText- 30]);

      var y = d3.scale.linear()
          .range([chartHeight + gapBetweenGroups, 0]);

      var yAxis = d3.svg.axis()
          .scale(y)
          .tickFormat('')
          .tickSize(0)
          .orient('left');

      var svg = d3.select(elem).append('svg')
          .attr('class', 'chart')
          .attr('width', chartWidth)
          .attr('height', chartHeight)
          .attr('transform', 'translate('+margin.left+', '+ margin.top +')');

      var bar = svg.selectAll('g')
          .data(zippedData)
          .enter().append('g')
          .attr('transform', function(d, i) {
            return 'translate(' + spaceForLabels + ',' + (i * barHeight + gapBetweenGroups * (0.5 + Math.floor(i/data.series.length))) + ')';
          });

      bar.append('rect')
          .attr('fill', function(d,i) { return bucket[i % data.series.length]; })
          .attr('class', 'bar')
          .attr('width', x)
          .attr('height', barHeight - 1);

      bar.append('text')
          .attr('x', function(d) { return x(d) + spaceValueText; })
          .attr('y', (barHeight / 2) - 0.75)
          .attr('fill', 'red')
          .attr('dy', '.35em')
          .text(function(d) {
            if(d) {
              return d + ' ' + unit; 
            } else {
              return '';
            }
          });

      bar.append('text')
          .attr('class', 'label')
          .attr('x', function(d) { return - 10; })
          .attr('y', groupHeight / 2)
          .attr('dy', '.35em')
          .text(function(d,i) {
            if (i % data.series.length === 0)
              return data.labels[Math.floor(i/data.series.length)];
            else
              return ''});

      svg.append('g')
            .attr('class', 'y axis')
            .attr('transform', 'translate(' + spaceForLabels + ', ' + -gapBetweenGroups/2 + ')')
            .call(yAxis);

      if(loader) {
        $el.removeClass(loader);
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

    buildPyramidChart: function(params) {
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
      var bucket = params.bucket;
      var margin = params.margin || {
        top: 30,
        right: 0,
        bottom: 0,
        left: 6,
        xaxis: 10,
        tooltip: 1.8,
        middle: 28
      };

      $el.addClass('graph-pyramid');

      var width = contentWidth,
          height = contentHeight;

      var width = width - margin.left - margin.right,
          height = height - margin.top - margin.bottom;
      var heightPadding = height - 50;

      var regionWidth = width/2 - margin.middle;
      var pointA = regionWidth,
          pointB = width - regionWidth;

      data.reverse();
      
      var totalPopulation = d3.sum(data, function(d) { return d.category2 + d.category1; });
      var percentage = function(d) { return d / totalPopulation; };

      var svg = d3.select(elem).append('svg')
        .attr('class', '')
        .attr('width', width + margin.left + margin.right)
        .attr('height', height + margin.top + margin.bottom)
        .append('g')
        .attr('transform', 'translate('+margin.left+', '+ margin.top +')');


      var maxValue = Math.max(
        d3.max(data, function(d) { return percentage(d.category2); }),
        d3.max(data, function(d) { return percentage(d.category1); })
      );

      var xScale = d3.scale.linear()
        .domain([0, maxValue])
        .range([0, regionWidth])
        .nice();

      var xScaleLeft = d3.scale.linear()
        .domain([0, maxValue])
        .range([regionWidth, 0]);

      var xScaleRight = d3.scale.linear()
        .domain([0, maxValue])
        .range([0, regionWidth]);

      var yScale = d3.scale.ordinal()
        .domain(data.map(function(d) { return d.group; }))
        .rangeRoundBands([height,0], 0.1);

      var yAxisLeft = d3.svg.axis()
        .scale(yScale)
        .orient('right')
        .tickSize(4,0)
        .tickPadding(margin.middle-4);

      var yAxisRight = d3.svg.axis()
        .scale(yScale)
        .orient('left')
        .tickSize(4,0)
        .tickFormat('');

      var leftBarGroup = svg.append('g')
        .attr('class', 'barsContainer')
        .attr('transform', translation(pointA, 0) + 'scale(-1,1)');
      var rightBarGroup = svg.append('g')
        .attr('class', 'barsContainer')
        .attr('transform', translation(pointB, 0));

      svg.append('g')
        .attr('class', 'axis y left')
        .attr('transform', translation(pointA, 0))
        .call(yAxisLeft)
        .selectAll('text')
        .style('text-anchor', 'middle');

      svg.append('g')
        .attr('class', 'axis y right')
        .attr('transform', translation(pointB, 0))
        .call(yAxisRight);

      leftBarGroup.selectAll('.bar.left')
        .data(data)
        .enter().append('rect')
          .attr('class', 'bar left')
          .attr('x', 0)
          .attr('y', function(d) { return yScale(d.group); })
          .attr('fill', function(d) { return d.color2 })
          .attr('width', function(d) { return xScale(percentage(d.category2)); })
          .attr('height', yScale.rangeBand());

      svg.append('g')
        .attr('transform', translation(pointA, 0)).append('text')
        .attr('x', function(d) { return 0 })
        .attr('y', '-10')
        .attr('fill', 'red')
        .attr('dy', '.35em')
        .attr('text-anchor', 'end')
        .text(function(d) { return data[0].label2;});

      rightBarGroup.selectAll('.bar.right')
        .data(data)
        .enter().append('rect')
          .attr('class', 'bar right')
          .attr('x', 0)
          .attr('fill', function(d) { return d.color1 })
          .attr('y', function(d) { return yScale(d.group); })
          .attr('width', function(d) { return xScale(percentage(d.category1)); })
          .attr('height', yScale.rangeBand());

      svg.append('g')
          .attr('transform', translation(pointB, 0)).append('text')
          .attr('x', function(d) { return 0 })
          .attr('y', '-10')
          .attr('fill', 'red')
          .attr('dy', '.35em')
          .attr('text-anchor', 'start')
          .text(function(d) { return data[0].label1; });

      function translation(x,y) {
        return 'translate(' + x + ',' + y + ')';
      }

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
          .attr('class', 'value number noLabel');


        function tooltipData(value) {
          var element = d3.select(elem+' svg');
          var cords = d3.mouse(element.node());

          d3.select(tooltipEl)
            .style('left', ( cords[0] - (tooltipW / 2)) + 'px')
            .style('top', ( cords[1] - tooltipH + (tooltipH/5) ) + 'px')
            .style('display', 'block');

          d3.select(tooltipEl)
            .select('.value')
            .text(value);
        }

        d3.selectAll(elem+' .left').on('mousemove', function (d) {
          if(d) {
            tooltipData(d.category2);
          }
        });

        d3.selectAll(elem+' .right').on('mousemove', function (d) {
          if(d) {
            tooltipData(d.category1);
          }
        });

        d3.selectAll(elem+' .barsContainer').on('mouseleave', function () {
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

      var layer = barsContent.selectAll('.layer')
          .data(data)
        .enter().append('g')
          .attr('class', 'layer')
          .style('fill', function(d, i) { return bucket[i]; });

      layer.selectAll('rect')
        .data(function(d) { return d; })
        .enter().append('rect')
        .attr('y', function(d, i) { return y(d.x) + ((y(i) / 10) - 6); })
        .attr('x', function(d) { return x(d.y0); })
        .attr('height', barHeight)
        .attr('width', function(d) { return x(d.y); });


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

    buildScatterChart: function(params) {
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
      var unit = params.unit || '';
      var unitY = params.unitY || '';
      var unitX = params.unitX || '';
      var margin = params.margin || {
        top: 30,
        right: 0,
        bottom: 40,
        left: 0,
        xaxis: 10,
        tooltip: 1.8
      };

      $el.addClass('graph-scatter');

      var width = contentWidth - margin.left - margin.right,
          height = contentHeight - margin.top - margin.bottom;

      var svg = d3.select(elem).append('svg')
        .attr('width', width + margin.left + margin.right)
        .attr('height', height + margin.top + margin.bottom)
        .append('g')
          .attr('transform', 'translate('+margin.left+',' + margin.top + ')');

      var x = d3.scale.ordinal()
        .rangeRoundBands([0, width], .4);
      x.domain(data.map(function(d) { return d.x; }));

      var yMin = d3.min(data,function(d){ return d.y; });
      var yMax = d3.max(data, function(d) { return d.y; });

      var y = d3.scale.linear()
        .domain([yMin, yMax])
        .range([height,yMin]);

      svg.append('g').attr('class', 'x axis')
        .attr('transform', 'translate(0,' + y.range()[0] + ')');
      svg.append('g').attr('class', 'y axis');

      var xAxis = d3.svg.axis()
        .scale(x)
        .orient('bottom')
        .ticks(5)
        .tickSize(0)
        .tickFormat('')
        .tickPadding(10);

      var yAxis = d3.svg.axis()
        .scale(y)
        .orient('left')
        .innerTickSize(-width)
        .outerTickSize(0)
        .tickPadding(6)
        .tickFormat('')
        .ticks(6);

      svg.selectAll('g.y.axis').call(yAxis);
      svg.selectAll('g.x.axis').call(xAxis);

      svg.append("g")
        .attr("class", "y axis")
        .append("line")
          .attr("y1", yMin >= 0 ? height : y(0))
          .attr("y2", yMin >= 0 ? height : y(0))
          .attr("x1", 0)
          .attr("x2", width);

      var groups = svg.selectAll('g.node').data(data, function (d) {
        return d.name;
      });
      
      var dotsGroup = groups.enter().append('g').attr('class', 'node')
      .attr('transform', function (d) {
        return 'translate(' + x(d.x) + ',' + y(d.y) + ')';
      });

      dotsGroup.append('circle')
        .attr('r', 10)
        .attr('class', 'dot')
        .style('fill', function (d) {
          return d.color;
      });

      svg.append('g')
        .attr('transform', 'translate(-5, -10)').append('text')
        .attr('class', 'unit')
        .attr('x', function(d) { return 0 })
        .attr('y', '-10')
        .attr('dy', '.35em')
        .attr('text-anchor', 'start')
        .text(function(d) { return unitY; });
      
      svg.append('g')
        .attr('transform', 'translate('+ (width) +', '+ (height + (margin.bottom / 2) )+')').append('text')
        .attr('class', 'unit')
        .attr('x', function(d) { return 0 })
        .attr('y', '0')
        .attr('dy', '.35em')
        .attr('text-anchor', 'start')
        .text(function(d) { return unitX; });

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

        d3.selectAll(elem+' .dot').on('mousemove', function (d) {
          var element = d3.select(elem+' svg');
          var cords = d3.mouse(element.node());

          d3.select(tooltipEl)
            .style('left', ( cords[0] - (tooltipW / 2)) + 'px')
            .style('top', ( cords[1] - tooltipH - (tooltipH/3) ) + 'px')
            .style('display', 'block');

          d3.select(tooltipEl)
            .select('.value')
            .text(d.x).append('span')
            .attr('class', 'tooltip-unit')
            .text(unit);
        });

        d3.selectAll(elem+' .dot').on('mouseout', function () {
            d3.select(tooltipEl)
              .style('display', 'none');
        });
      }
    },

    buildErrorChart: function(params) {
      var elem = params.elem;
      var elemAttr = elem.replace(/[#]|[.]/g, '');
      var $el = $(elem);
      var contentWidth = $el.width();
      var contentHeight = $el.height();
      var data = params.data;
      var compareData = params.compareData || null;
      var hover = params.hover;
      var loader = params.loader || null;
      var infoWindow = params.infoWindowText || '';
      var decimals = params.decimals || 0;
      var unit = params.unit || ''; 
      var unitZ = params.unitZ || ''; 
      var barWidth = params.barWidth || 10;
      var barSeparation = params.barSeparation || 10;
      var xIsDate = params.xIsDate || false;
      var hasLine = params.hasLine || false;
      var interpolate = params.interpolate || 'linear';
      var transition = 200;
      var margin = params.margin || {
        top: 30,
        right: 65,
        bottom: 30,
        left: 30,
        xaxis: 10,
        tooltip: 1.8,
        label: 18
      };

      $el.addClass('graph-line graph-error');

      var circleSize = 5;
      var compareMargin = 150;
      var headerHeight = 18;
      var headerSpacing = (headerHeight / 2);
      var barDefaultWidth;
      var barWithCompareWidth = .76;
      var barWithoutCompare = .83;

      var width = contentWidth,
          height = contentHeight;

      var width = width - margin.left - margin.right,
          height = height - margin.top - margin.bottom;
      var groupWidth = width;

      var svg = d3.select(elem).append('svg')
        .attr('class', '')
        .attr('width', width + margin.left + margin.right)
        .attr('height', height + margin.top + margin.bottom)
        .append('g')
          .attr('transform', 'translate('+(margin.left * 2)+', '+ margin.top +')');

      if(compareData) {
        groupWidth = groupWidth - compareMargin;
        barDefaultWidth = barWithCompareWidth;
      } else {
        compareMargin = 0;
        groupWidth = width;
        barDefaultWidth = barWithoutCompare;        
      }

      // Domain Graph
      var x = d3.scale.ordinal()
        .rangeRoundBands([0, width], .83);
      x.domain(data.map(function(d) { return d.x; }));

      var yMin = d3.min(data,function(d){ return d.y - d.z; });
      var yMax = d3.max(data, function(d) { return d.y + d.z; });

      var y = d3.scale.linear()
        .domain([yMin, yMax])
        .range([height,0]).nice();

      // General Axis
      var xAxis = d3.svg.axis()
        .scale(x)
        .orient('bottom')
        .ticks(8)
        .tickSize(0)
        .tickFormat('')
        .tickPadding(10);

      var yAxis = d3.svg.axis()
        .scale(y)
        .orient('left')
        .ticks(4)
        .innerTickSize(-width)
        .outerTickSize(0)
        .tickPadding(4)
        .ticks(8);

      svg.append('g')
          .attr('class', 'y axis')
          .call(yAxis);

      svg.append('g')
          .attr('class', 'x axis')
          .attr('transform', 'translate(0,' + height + ')')
          .call(xAxis);

      var groupData = svg.append('g')
          .attr('class', 'group')
          .attr('transform', 'translate('+compareMargin+', 0)');

      var groupCompare = svg.append('g')
          .attr('class', 'group')
          .attr('transform', 'translate(0, 0)');

      function renderData(isCompare, dataGroup, group) {
        if(isCompare) {
          groupWidth = compareMargin;
          compareMargin = 0;
        }

        // Domain Group
        var xGroup = d3.scale.ordinal()
          .rangeRoundBands([0, groupWidth], barDefaultWidth);
        xGroup.domain(dataGroup.map(function(d) { return d.x; }));

        var yGroupMin = d3.min(data,function(d){ return d.y - d.z; });
        var yGroupMax = d3.max(data, function(d) { return d.y + d.z; });

        var yGroup = d3.scale.linear()
          .domain([yGroupMin, yGroupMax])
          .range([height,0]).nice();

        // Group
        var barsGroup = group.selectAll('.bar')
            .data(dataGroup)
          .enter().append('rect')
            .attr('class', 'bar')
            .style('fill', function(d) { return d.color; })
            .attr('x', function(d) { return xGroup(d.x); })
            .attr('width', xGroup.rangeBand()) 
            .attr('y', function(d) { return yGroup(Math.max(0, d.y)); })
            .attr('height', function(d) { return yMin >= 0 ? Math.abs(height - yGroup(d.y)) : Math.abs(yGroup(d.y) - yGroup(0)); })

        var lines = group.selectAll('.lines')
          .data(dataGroup)
            .enter().append('g');

        lines.append('line')
          .attr('y1', function(d){ return yGroup(d.y + d.z);})
          .attr('y2', function(d){ return yGroup(d.y);})
          .attr('x1', function(d){ return xGroup(d.x) + (xGroup.rangeBand() / 2);})
          .attr('x2', function(d){ return xGroup(d.x) + (xGroup.rangeBand() / 2);})
          .attr('class', 'errorLine');
        lines.append('line')
          .attr('y1', function(d){ return yGroup(d.y);})
          .attr('y2', function(d){ return yGroup(-(d.z - d.y));})
          .attr('x1', function(d){ return xGroup(d.x) + (xGroup.rangeBand() / 2);})
          .attr('x2', function(d){ return xGroup(d.x) + (xGroup.rangeBand() / 2);})
          .attr('class', 'errorLine');

        lines.append('line')
          .attr('y1', function(d){ return yGroup(d.y + d.z);})
          .attr('y2', function(d){ return yGroup(d.y + d.z);})
          .attr('x1', function(d){ return xGroup(d.x) + (xGroup.rangeBand() / 4)})
          .attr('x2', function(d){ return xGroup(d.x) + (xGroup.rangeBand() - (xGroup.rangeBand() / 4));})
          .attr('class', 'errorLine');
        lines.append('line')
          .attr('y1', function(d){ return yGroup(-(d.z - d.y));})
          .attr('y2', function(d){ return yGroup(-(d.z - d.y));})
          .attr('x1', function(d){ return xGroup(d.x) + (xGroup.rangeBand() / 4)})
          .attr('x2', function(d){ return xGroup(d.x) + (xGroup.rangeBand() - (xGroup.rangeBand() / 4));})
          .attr('class', 'errorLine');

        if(!isCompare) {
          svg.append('g')
              .attr('class', 'y axis')
            .append('line')
              .attr('y1', yMin >= 0 ? height : y(0))
              .attr('y2', yMin >= 0 ? height : y(0))
              .attr('x1', 0)
              .attr('x2', width);
        } else {
          svg.append('g')
            .attr('transform', 'translate('+groupWidth+', '+ -(headerHeight + headerSpacing) +')')
            .append('rect')
            .attr('width', (xGroup.rangeBand() / 2) + 'px')
            .attr('height', height + headerHeight + 'px')
            .attr('class', 'divider');
        }

        var groupCircles = svg.append('g')
          .attr('class', 'group')
          .attr('transform', 'translate('+compareMargin+', 0)');

        groupCircles.selectAll('.circle')
          .data(dataGroup)
            .enter().append('circle')
              .attr('class','circle')
              .attr('cx', function(d) { return xGroup(d.x) + (xGroup.rangeBand() / 2);})
              .attr('cy', function(d){return yGroup(d.y);})
              .attr('r', circleSize)
              .style('stroke', 'transparent');

        // Label
        var labelGroup = group.append('g')
          .attr('transform', 'translate(0, '+ -headerHeight +')');

        labelGroup.append('text')
          .attr('x', function(d) { return groupWidth / 2 })
          .attr('class', 'labelText')
          .text(function() {
            var text = '';
            if(dataGroup && dataGroup[0] && dataGroup[0].category) {
              text = dataGroup[0].category;
            }
            return text;
          });

      }

      renderData(false, data, groupData);

      if(compareData) {
        renderData(true, compareData, groupCompare);
      }

      d3.select(elem+' svg').append('g')
        .attr('transform', 'translate('+ margin.label +', '+ height / 2 +') rotate(-90,10,20)').append('text')
        .attr('class', 'unit')
        .attr('x', function(d) { return 0 })
        .attr('y', '0')
        .attr('dy', '.35em')
        .attr('text-anchor', 'middle')
        .text(function(d) { return unit });

      if(loader) {
        $el.removeClass(loader);
      }

    }
  });

})(this);