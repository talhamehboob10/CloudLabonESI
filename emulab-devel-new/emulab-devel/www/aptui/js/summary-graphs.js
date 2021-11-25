$(function ()
{
    'use strict';

    var templates = APT_OPTIONS.fetchTemplateList(['summary-graphs']);
    var templateString = templates['summary-graphs'];
    var isadmin           = 0;

    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);
	isadmin = window.ISADMIN;

	ShowGraphs();
    }

    function ShowGraphs()
    {
	var callback = function(json) {
	    console.log(json);
	    
	    $('#page-body').html(templateString);
	    PlotGraph(json.value.oneday, "duration_oneday");
	    PlotGraph(json.value.month, "duration_month");
	}
	var xmlthing = sup.CallServerMethod(null, "sumstats",
					    "GetDurationInfo", null);
	xmlthing.done(callback);
    }

    function PlotGraph(duration_data, id)
    {
	var data = duration_data.durations;
	
	// need to sort for plotting
	data.sort(function(a, b) {
	    return a.x - b.x;
	});

	// A formatter for counts.
	var formatCount = d3.format(",.0f");

	var margin = {top: 10, right: 30, bottom: 30, left: 50};
	var width  = parseInt(d3.select('#' + id).style('width'), 10)
	    - margin.left - margin.right;
	var height = 400 - margin.top - margin.bottom;

	var x = d3.scale.ordinal()
	    .domain(data.map(function(d) { return d.x; }))
	    .rangeRoundBands([0, width], 0.1);

	// Generate a histogram using uniformly-spaced bins.
	//var data = d3.layout.histogram()
	//    .bins(x.ticks(24))(values);

	var y = d3.scale.linear()
	    .domain([0, d3.max(data, function(d) { return d.y; })])
	    .range([height, 0]);

	var xAxis = d3.svg.axis()
	    .scale(x)
	    .orient("bottom");

	var yAxis = d3.svg.axis()
	    .scale(y)
	    .orient("left");

	var svg = d3.select("#" + id).append("svg")
	    .attr("width", width + margin.left + margin.right)
	    .attr("height", height + margin.top + margin.bottom)
	    .append("g")
	    .attr("transform",
		  "translate(" + margin.left + "," + margin.top + ")");

	var bar = svg.selectAll(".bar")
	    .data(data)
	    .enter().append("g")
            .attr("class", "bar");

	bar.append("rect")
 	    .attr("x", function(d) { return x(d.x); })
	    .attr("y", function(d) { return y(d.y); })
	    .attr("width", x.rangeBand())
	    .attr("height", function(d) { return height - y(d.y); });

	bar.append("text")
	    .attr("dy", ".75em")
	    .attr("y", function(d) { return y(d.y) - 10; })
	    .attr("x", function(d) { return x(d.x) + (x.rangeBand() / 2); })
	    .attr("text-anchor", "middle")
	    .text(function(d) { return d.y; });

	svg.append("g")
	    .attr("class", "x axis")
	    .attr("transform", "translate(0," + height + ")")
	    .call(xAxis);
	
	svg.append("g")
	    .attr("class", "y axis")
	    .call(yAxis);

	if (0) {
	svg.append("text")
	    .attr("transform","rotate(-90)")
	    .attr("y", 0 - 100)
	    .attr("x", 0 - 100)
	    .attr("dy","1em")
	    .text("Number of Experiments");
	
	svg.append("text")
	    .attr("class","title")
	    .attr("x", (width / 2))
	    .attr("y", 10)
	    .attr("text-anchor", "middle")  
	    .style("font-size", "16px") 
	    .style("text-decoration", "underline")  
	    .text("Experiment duration in hours (up to 36 hours)");
	}
    }

    function gaussian(x,mean,sigma) {
	return ((1 / (sigma * Math.sqrt(2 * Math.PI))) *
            Math.exp(-((x - mean) * (x - mean) / (2 * sigma * sigma))))
		* 10200;
    };

    function PlotLenthsNoWork(duration_data)
    {
	var data   = duration_data.durations;
	var mean   = duration_data.average;
	var sigma  = duration_data.stddev;

	data = data.map(function(a) {
	    return { "y" : gaussian(a.x, mean, sigma), "x" : a.x, "oy":a.y};
	});
	console.log(data);
	
	// need to sort for plotting
	data.sort(function(a, b) {
	    return a.x - b.x;
	});
	console.log(data);

	// line chart based on http://bl.ocks.org/mbostock/3883245
	var margin = {
            top: 20,
            right: 20,
            bottom: 30,
            left: 50
	},
	width = 800 - margin.left - margin.right,
	height = 500 - margin.top - margin.bottom;

	var x = d3.scale.linear()
	    .range([0, width]);

	var y = d3.scale.linear()
	    .range([height, 0]);

	var xAxis = d3.svg.axis()
	    .scale(x)
	    .orient("bottom");

	var yAxis = d3.svg.axis()
	    .scale(y)
	    .orient("left");

	var line = d3.svg.line()
	    .x(function(d) {
		return x(d.x);
	    })
	    .y(function(d) {
		return y(d.y);
	    });

	var svg = d3.select("#duration_graph").append("svg")
	    .attr("width", width + margin.left + margin.right)
	    .attr("height", height + margin.top + margin.bottom)
	    .append("g")
	    .attr("transform", "translate(" + margin.left + "," +
		  margin.top + ")");

	if (0) {
	x.domain(d3.extent(data, function(d) {
	    return d.x;
	}));
	y.domain(d3.extent(data, function(d) {
	    return d.y;
	}));
	}
	x.domain([0,24]);
	y.domain(d3.extent(data, function(d) {
	    return d.oy;
	}));

	svg.append("g")
	    .attr("class", "x axis")
	    .attr("transform", "translate(0," + height + ")")
	    .call(xAxis);

	svg.append("g")
	    .attr("class", "y axis")
	    .call(yAxis);

	svg.append("path")
	    .datum(data)
	    .attr("class", "line")
	    .attr("d", line);

    }
    $(document).ready(initialize);
});
