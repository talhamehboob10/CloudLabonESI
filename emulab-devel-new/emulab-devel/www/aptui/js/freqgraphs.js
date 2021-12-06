//
// Frequency graphs, data from the monitors on the FEs/MEs/BSs.
//
// This code is mostly stolen from various example graphs on the D3
// tutorial website. 
//
$(function () {
window.ShowFrequencyGraph = (function ()
{
    'use strict';
    var d3 = d3v5;

    function CreateGraph(args, data) {
	//console.log(data);
	
	var selector     = args.selector + " .frequency-graph-subgraph";
	var parentWidth  = $(selector).width();
	var parentHeight = $(selector).height();
	// Not all data files have the incident value.
	var hasIncident  = false;
	var lineI;

	var margin  = {top: 20, right: 20, bottom: 130, left: 55};
	var width   = parentWidth - margin.left - margin.right;
	var height  = parentHeight - margin.top - margin.bottom;
	var margin2 = {top: parentHeight - 80,
		       right: 20, bottom: 30, left: 55};
	var height2 = parentHeight - margin2.top - margin2.bottom;

	// Clear old graph
	$(selector).html("");

	console.info(margin, margin2);
	console.info(width, height, height2);

	var bisector = d3.bisector(function(d) { return d.frequency; }).left;
	var formatter = d3.format(".3f");

	var x = d3.scaleLinear().range([0, width]),
	    x2 = d3.scaleLinear().range([0, width]),
	    y = d3.scaleLinear().range([height, 0]),
	    y2 = d3.scaleLinear().range([height2, 0]);

	var xAxis = d3.axisBottom(x),
	    xAxis2 = d3.axisBottom(x2),
	    yAxis = d3.axisLeft(y);

	var brush = d3.brushX()
	    .extent([[0, 0], [width, height2]])
	    .on("brush end", brushed);

	var zoom = d3.zoom()
	    .scaleExtent([1, Infinity])
	    .translateExtent([[0, 0], [width, height]])
	    .extent([[0, 0], [width, height]])
	    .on("zoom", zoomed);

	var line = d3.line().curve(d3.curveStep)
            .x(function (d) { return x(d.frequency); })
            .y(function (d) { return y(d.power); });

	if (hasIncident) {
	    lineI = d3.line().curve(d3.curveStep)
		.x(function (d) { return x(d.frequency); })
		.y(function (d) { return y(d.incident); });
	}

	var line2 = d3.line().curve(d3.curveStep)
            .x(function (d) { return x2(d.frequency); })
            .y(function (d) { return y2(d.power); });

	var svg = d3.select(selector)
	    .append('svg')
            .attr("width", $(selector).width())
            .attr("height", $(selector).height());
	
	var clip = svg.append("defs").append("svg:clipPath")
            .attr("id", "clip")
            .append("svg:rect")
            .attr("width", width)
            .attr("height", height)
            .attr("x", 0)
            .attr("y", 0); 

	var Line_chart = svg.append("g")
            .attr("class", "focus")
            .attr("transform",
		  "translate(" + margin.left + "," + margin.top + ")")
	    .attr("clip-path", "url(#clip)");

	var focus = svg.append("g")
            .attr("class", "focus")
            .attr("transform",
		  "translate(" + margin.left + "," + margin.top + ")");

	var context = svg.append("g")
	    .attr("class", "context")
	    .attr("transform",
		  "translate(" + margin2.left + "," + margin2.top + ")");

	x.domain(d3.extent(data, function(d) { return d.frequency; }));
	// I want a little more pad above and below
	var power_extents = d3.extent(data, function(d) { return d.power; });
	console.info(power_extents);
	power_extents[0] = power_extents[0] - 2;
	power_extents[1] = power_extents[1] + 2;
	console.info(power_extents);
	y.domain(power_extents);
	x2.domain(x.domain());
	y2.domain(y.domain());

	focus.append("g")
	    .attr("class", "axis axis--x")
	    .attr("transform", "translate(0," + height + ")")
	    .call(xAxis);

	// text label for the x axis
	focus.append("text")             
	    .attr("y", height + margin.top + 15)
	    .attr("x", (width / 2))
	    .style("text-anchor", "middle")
	    .text("Frequency (MHz)");

	focus.append("g")
	    .attr("class", "axis axis--y")
	    .call(yAxis);

	// text label for the y axis
	focus.append("text")
	    .attr("transform", "rotate(-90)")
	    .attr("y", 0 - margin.left)
	    .attr("x",0 - (height / 2))
	    .attr("dy", "1em")
	    .style("text-anchor", "middle")
	    .text("Power (dB)");
	
	Line_chart.append("path")
	    .datum(data)
	    .attr("class", "line line-power")
	    .attr("d", line);

	if (hasIncident) {
	    Line_chart.append("path")
		.datum(data)
		.attr("class", "line line-incident")
		.attr("d", lineI);
	}

	var tooltip = Line_chart.append("g")
	    .attr("class", "tooltip")
	    .style("opacity", "1.0")
	    .style("display", "none");

	tooltip.append("circle")
	    .attr("r", 5);

	var toolbox = tooltip.append("g")
	    .attr("class", "tooltip-box")
            .attr("transform", "translate(10,0)");

	toolbox.append("rect")
	    .attr("class", "tooltip-rect")
	    .attr("width", 130)
	    .attr("height", 95)
            .attr("y", -22)
	    .attr("rx", 4)
	    .attr("ry", 4);

	toolbox.append("text")
	    .attr("x", 5)
	    .attr("y", -2)
	    .text("Freq:");

	toolbox.append("text")
	    .attr("class", "tooltip-freq")
	    .attr("x", 65)
	    .attr("y", -2);

	toolbox.append("text")
	    .attr("x", 5)
	    .attr("y", 18)
	    .text("Power:");

	toolbox.append("text")
	    .attr("class", "tooltip-power")
	    .attr("x", 65)
	    .attr("y", 18);

	toolbox.append("text")
	    .attr("x", 5)
	    .attr("y", 38)
	    .text("Center:");

	toolbox.append("text")
	    .attr("class", "tooltip-center")
	    .attr("x", 65)
	    .attr("y", 38);

	if (hasIncident) {
	    toolbox.append("text")
		.attr("x", 5)
		.attr("y", 58)
		.attr("class", "line-incident")
		.text("Incident:");

	    toolbox.append("text")
		.attr("class", "tooltip-incident")
		.attr("x", 65)
		.attr("y", 58);
	}

	context.append("path")
	    .datum(data)
	    .attr("class", "line")
	    .attr("d", line2);

	context.append("g")
	    .attr("class", "axis axis--x")
	    .attr("transform", "translate(0," + height2 + ")")
	    .call(xAxis2);

	context.append("g")
	    .attr("class", "brush")
	    .call(brush)
	    .call(brush.move, x.range());

	svg.append("rect")
	    .attr("class", "zoom")
	    .attr("width", width)
	    .attr("height", height)
	    .attr("transform",
		  "translate(" + margin.left + "," + margin.top + ")")
	    .call(zoom)
	    .on("mouseover", function() { tooltip.style("display", null); })
	    .on("mouseout", function() { tooltip.style("display", "none");})
	    .on("mousemove", mousemove);

	function mousemove() {
	    var x0 = x.invert(d3.mouse(this)[0]),
		i = bisector(data, x0, 1),
		d0 = data[i - 1],
		d1 = data[i];
	    
	    var d = x0 - d0.frequency > d1.frequency - x0 ? d1 : d0;
	    //console.info(x0, d, x(d.frequency));

	    // Move the box to the left/right of the circle, if
	    // its near the right/left margin.
	    if (x(d.frequency) > width - 150) {
		toolbox.attr("transform", "translate(-140,0)");
	    }
	    else {
		toolbox.attr("transform", "translate(10,0)");
	    }
	    
	    tooltip.attr("transform",
			 "translate(" + x(d.frequency) +
			 "," + y(d.power) + ")");
	    tooltip.select(".tooltip-freq").text(formatter(d.frequency));
	    tooltip.select(".tooltip-power").text(formatter(d.power));
	    if (_.has(d, "center_freq")) {
		tooltip.select(".tooltip-center")
		    .text(formatter(d.center_freq));
	    }
	    else {
		tooltip.select(".tooltip-center").text("n/a");
	    }
	    if (hasIncident) {
		if (_.has(d, "incident")) {
		    tooltip.select(".tooltip-incident")
			.text(formatter(d.incident));
		}
		else {
		    tooltip.select(".tooltip-incident").text("n/a");
		}
	    }
	}

	function brushed() {
	    if (d3.event.sourceEvent && d3.event.sourceEvent.type === "zoom")
		return; // ignore brush-by-zoom
	    var s = d3.event.selection || x2.range();
	    x.domain(s.map(x2.invert, x2));
	    Line_chart.select(".line-power").attr("d", line);
	    if (hasIncident) {
		Line_chart.select(".line-incident").attr("d", lineI);
	    }
	    focus.select(".axis--x").call(xAxis);
	    svg.select(".zoom").call(zoom.transform, d3.zoomIdentity
				     .scale(width / (s[1] - s[0]))
				     .translate(-s[0], 0));
	}

	function zoomed() {
	    if (d3.event.sourceEvent && d3.event.sourceEvent.type === "brush")
		return; // ignore zoom-by-brush
	    var t = d3.event.transform;
	    x.domain(t.rescaleX(x2).domain());
	    Line_chart.select(".line-power").attr("d", line);
	    if (hasIncident) {
		Line_chart.select(".line-incident").attr("d", lineI);
	    }
	    focus.select(".axis--x").call(xAxis);
	    context.select(".brush")
		.call(brush.move, x.range().map(t.invertX, t));
	}
    }

    function CreateBins(data)
    {
	var result = [];
	var bins   = [];
	// Not all data files have the incident value.
	var hasIncident  = false;
	console.info("CreateBins: ", data);

	_.each(data, function (d, index) {
	    var freq  = +d.frequency;
	    var power = +d.power;
	    var x     = Math.floor(freq);

	    if (!_.has(bins, x)) {
		var bin = {
		    "frequency" : x,
		    "max"       : power,
		    "min"       : power,
		    "avg"       : power,
		    "samples"   : [d],
		};
		if (hasIncident) {
		    bin["imax"] = +d.incident;
		}
		bins[x] = bin;
		result.push(bin);
		return;
	    }
	    var bin = bins[x];
	    if (power > bin.max) {
		bin.max = power;
	    }
	    if (power < bin.min) {
		bin.min = power;
	    }
	    if (hasIncident) {
		var inci = +d.incident;
		if (inci > bin.imax) {
		    bin.imax = inci;
		}
	    }
	    bin.samples.push(d);
	    var sum = 0;
	    _.each(bin.samples, function (d) {
		sum  += d.power;
	    });
	    bin.avg  = sum / _.size(bin.samples);
	});
	//console.info("bins", result);
	return result;
    }

    var tooltipTemplate =
	'  <table class="table table-condensed border-none" ' +
	'         style="font-size: 14px;">' +
	'    <tbody>' +
	'      <tr>' +
	'        <td class="border-none">Frequency:</td>' +
	'        <td class="border-none tooltip-frequency"></td>' +
	'      </tr>' +
	'      <tr>' +
	'        <td class="border-none">Avg Power:</td>' +
	'        <td class="border-none tooltip-avg"></td>' +
	'      </tr>' +
	'      <tr>' +
	'        <td class="border-none">Max Power:</td>' +
	'        <td class="border-none tooltip-max"></td>' +
	'      </tr>' +
	'      <tr>' +
	'        <td class="border-none">Min Power:</td>' +
	'        <td class="border-none tooltip-min"></td>' +
	'      </tr>' +
	'      <tr class="hidden tooltip-incident">' +
	'        <td class="border-none">Incident Max:</td>' +
	'        <td class="border-none incident"></td>' +
	'      </tr>' +
	'    </tbody>' +
	'  </table>';
    
    function CreateBinGraph(args, data) {
	var bins         = CreateBins(data);
	var selector     = args.selector + " .frequency-graph-maingraph";
	var parentWidth  = $(selector).parent().width();
	var parentHeight = $(selector).parent().height();
	var ParentTop    = $(selector).parent().position().top;
	var ParentLeft   = $(selector).parent().position().left;
	var hasIncident  = false;
	var lineI;

	// Clear old graph
	$(selector).html("");
	// And the sub graph.
	$(args.selector + " .frequency-graph-subgraph").html("");
	
	var margin  = {top: 20, right: 20, bottom: 130, left: 55};
	var width   = parentWidth - margin.left - margin.right;
	var height  = parentHeight - margin.top - margin.bottom;
	var margin2 = {top: parentHeight - 80,
		       right: 20, bottom: 30, left: 55};
	var height2 = parentHeight - margin2.top - margin2.bottom;

	console.info(margin, margin2);
	console.info(parentWidth, parentHeight, ParentTop, ParentLeft);
	console.info(width, height, height2);

	var bisector = d3.bisector(function(d) { return d.frequency; }).left;
	var formatter = d3.format(".3f");

	var x = d3.scaleLinear().range([0, width]),
	    x2 = d3.scaleLinear().range([0, width]),
	    y = d3.scaleLinear().range([height, 0]),
	    y2 = d3.scaleLinear().range([height2, 0]);

	var xAxis = d3.axisBottom(x),
	    xAxis2 = d3.axisBottom(x2),
	    yAxis = d3.axisLeft(y);

	var brush = d3.brushX()
	    .extent([[0, 0], [width, height2]])
	    .on("brush end", brushed);

	var zoom = d3.zoom()
	    .scaleExtent([1, Infinity])
	    .translateExtent([[0, 0], [width, height]])
	    .extent([[0, 0], [width, height]])
	    .on("zoom", zoomed);

	var line = d3.line().curve(d3.curveStep)
            .x(function (d) { return x(d.frequency); })
            .y(function (d) { return y(d.max); });

	if (hasIncident) {
	    lineI = d3.line().curve(d3.curveStep)
		.x(function (d) { return x(d.frequency); })
		.y(function (d) { return y(d.imax); });
	}

	var line2 = d3.line().curve(d3.curveStep)
            .x(function (d) { return x2(d.frequency); })
            .y(function (d) { return y2(d.max); });

	var svg = d3.select(selector)
	    .append('svg')
            .attr("width", $(selector).width())
            .attr("height", $(selector).height());
	
	var clip = svg.append("defs").append("svg:clipPath")
            .attr("id", "clip")
            .append("svg:rect")
            .attr("width", width)
            .attr("height", height)
            .attr("x", 0)
            .attr("y", 0); 

	var Line_chart = svg.append("g")
            .attr("class", "focus")
            .attr("transform",
		  "translate(" + margin.left + "," + margin.top + ")")
	    .attr("clip-path", "url(#clip)");

	var focus = svg.append("g")
            .attr("class", "focus")
            .attr("transform",
		  "translate(" + margin.left + "," + margin.top + ")");

	var context = svg.append("g")
	    .attr("class", "context")
	    .attr("transform",
		  "translate(" + margin2.left + "," + margin2.top + ")");

	x.domain(d3.extent(bins, function(d) { return d.frequency; }));
	y.domain(d3.extent(bins, function(d) { return d.max; }));
	x2.domain(x.domain());
	y2.domain(y.domain());

	focus.append("g")
	    .attr("class", "axis axis--x")
	    .attr("transform", "translate(0," + height + ")")
	    .call(xAxis);

	// text label for the x axis
	focus.append("text")             
	    .attr("y", height + margin.top + 15)
	    .attr("x", (width / 2))
	    .style("text-anchor", "middle")
	    .text("Frequency (MHz)");

	focus.append("g")
	    .attr("class", "axis axis--y")
	    .call(yAxis);

	// text label for the y axis
	focus.append("text")
	    .attr("transform", "rotate(-90)")
	    .attr("y", 0 - margin.left)
	    .attr("x",0 - (height / 2))
	    .attr("dy", "1em")
	    .style("text-anchor", "middle")
	    .text("Power (dB)");      
	
	Line_chart.append("path")
	    .datum(bins)
	    .attr("class", "line line-power")
	    .attr("d", line);

	if (hasIncident) {
	    Line_chart.append("path")
		.datum(bins)
		.attr("class", "line line-incident")
		.attr("d", lineI);
	}

	var tooltip = Line_chart.append("g")
	    .attr("class", "tooltip")
	    .style("opacity", "1.0")
	    .style("display", "none");

	tooltip.append("circle")
	    .attr("r", 5);

	context.append("path")
	    .datum(bins)
	    .attr("class", "line")
	    .attr("d", line2);

	context.append("g")
	    .attr("class", "axis axis--x")
	    .attr("transform", "translate(0," + height2 + ")")
	    .call(xAxis2);

	context.append("g")
	    .attr("class", "brush")
	    .call(brush)
	    .call(brush.move, x.range());

	svg.append("rect")
	    .attr("class", "zoom")
	    .attr("width", width)
	    .attr("height", height)
	    .attr("transform",
		  "translate(" + margin.left + "," + margin.top + ")")
	    .call(zoom)
	    .on("mouseover", ShowTooltip)
	    .on("mouseout", HideTooltip)
	    .on("mousemove", mousemove)
	    .on("click", DrawSubGraph);

	$('#tooltip-popover')
	    .popover({"content"   : tooltipTemplate,
		      "trigger"   : "manual",
		      "html"      : true,
		      "container" : selector,
		      "placement" : "auto",
		     });

	function HideTooltip()
	{
	    // The circle
	    tooltip.style("display", "none");;
	    // The box
	    $('#tooltip-popover').popover("hide");	    
	}

	function ShowTooltip()
	{
	    // The circle.
	    tooltip.style("display", null);
	}
    
	function mousemove() {
	    //console.info(d3.event, d3.mouse(this));
	    
	    var x0 = x.invert(d3.mouse(this)[0]),
		i = bisector(bins, x0, 1),
		d0 = bins[i - 1],
		d1 = bins[i];

	    var d = x0 - d0.frequency > d1.frequency - x0 ? d1 : d0;
	    //console.info(x0, d, x(d.frequency));
	    //console.info(x(d.frequency), y(d.avg));

	    tooltip.attr("transform",
			 "translate(" + x(d.frequency) +
			 "," + y(d.max) + ")");

	    // Bootstrap popover based tooltip.	    
	    var popover   = $('#tooltip-popover').data("bs.popover");
	    var isVisible = popover.tip().hasClass('in');
	    var updater   = function () {
		var content = popover.tip().find('.popover-content');
		var ptop    = Math.floor(ParentTop + y(d.max));
		var pleft   = Math.floor(ParentLeft + x(d.frequency));

		// Adjust ptop if its near the bottom or top.
		if (height - y(d.max) > popover.tip().height()) {
		    ptop = ptop + margin.top;
		}
		else {
		    ptop = ptop - (popover.tip().height() / 2);
		}
		// And pleft if too close to right side.
		if (x(d.frequency) > width - 150) {
		    pleft = pleft - 175;
		}
		else {
		    pleft = pleft + 70;
		}
		popover.tip().css("top", ptop + "px");
		popover.tip().css("left", pleft + "px");

		$(content).find(".tooltip-frequency")
		    .html(formatter(d.frequency));
		$(content).find(".tooltip-min")
		    .html(formatter(d.min));
		$(content).find(".tooltip-max")
		    .html(formatter(d.max));
		$(content).find(".tooltip-avg")
		    .html(formatter(d.avg));
		if (hasIncident) {
		    $(content).find(".tooltip-incident .incident")
			.html(formatter(d.imax));
		    $(content).find(".tooltip-incident")
			.removeClass("hidden");
		}
	    };
	    if (isVisible) {
		updater();
	    }
	    else {
		$('#tooltip-popover')
		    .on("inserted.bs.popover", function (event) {
			popover.tip().addClass("tooltip-popover")
			popover.tip().find(".arrow").remove();
			updater();
			$('#tooltip-popover').off("inserted.bs.popover");
		    });
		$('#tooltip-popover').popover('show');
	    }
	}

	function brushed() {
	    if (d3.event.sourceEvent && d3.event.sourceEvent.type === "zoom")
		return; // ignore brush-by-zoom
	    var s = d3.event.selection || x2.range();
	    x.domain(s.map(x2.invert, x2));
	    Line_chart.select(".line-power").attr("d", line);
	    if (hasIncident) {
		Line_chart.select(".line-incident").attr("d", lineI);
	    }
	    focus.select(".axis--x").call(xAxis);
	    svg.select(".zoom").call(zoom.transform, d3.zoomIdentity
				     .scale(width / (s[1] - s[0]))
				     .translate(-s[0], 0));
	}

	function zoomed() {
	    if (d3.event.sourceEvent && d3.event.sourceEvent.type === "brush")
		return; // ignore zoom-by-brush
	    var t = d3.event.transform;
	    x.domain(t.rescaleX(x2).domain());
	    Line_chart.select(".line-power").attr("d", line);
	    if (hasIncident) {
		Line_chart.select(".line-incident").attr("d", lineI);
	    }
	    focus.select(".axis--x").call(xAxis);
	    context.select(".brush")
		.call(brush.move, x.range().map(t.invertX, t));
	}
	/*
	 * Draw zoomed graph in lower panel, after user clicks on a point.
	 */
	function DrawSubGraph()
	{
	    var x0   = x.invert(d3.mouse(this)[0]);
	    var i    = bisector(bins, x0, 1);
	    var d    = bins[i];
	    var freq = d.frequency;
	    var subdata = [];
	    var index   = (i < 25 ? 0 : i - 25);

	    for (i = index; i < index + 50; i++) {
		// Hmm, the CSV file appears to not be well sorted within
		// a frequency bin. Must be a string sort someplace.
		var sorted = bins[i].samples
		    .sort(function (a, b) { return a.frequency - b.frequency});
		subdata = subdata.concat(sorted);
	    }
	    CreateGraph(args, subdata);
	}
	/*
	 * Draw a zoomed graph after user searches for min/max
	 */
	$(args.selector + " .frequency-search button").off("click");
	$(args.selector + " .frequency-search button").click(ZoomToSubGraph);
	
	function ZoomToSubGraph()
	{
	    var min = $.trim($(args.selector + " .min-freq-input").val());
	    var max = $.trim($(args.selector + " .max-freq-input").val());
	    
	    if (min == "" || max == "") {
		return;
	    }
	    var extents = d3.extent(bins, function(d) { return d.frequency; });
	    if (min < extents[0] || max > extents[1]) {
		alert("Search out of range: " + extents[0] + "," + extents[1]);
		return;
	    }
	    x.domain(extents);
	    console.info("ZoomToSubGraph", min, max, extents);
	    console.info(x(min), x(max));
	    context.select(".brush").call(brush.move, [x(min), x(max)]);
	}
    }
    function type(d) {
	d.frequency = +d.frequency;
	d.power     = +d.power;
	if (_.has(d, "incident")) {
	    d.incident = +d.incident;
	}
	return d;
    }

    function GetFrequencyData(datatype, route, method, args, callback)
    {
	var url = 'server-ajax.php';
	if (!datatype) {
	    datatype = "text";
	}

	var networkError = {
	    "code"  : -1,
	    "value" : "Server error, possible network failure.",
	};

	var jqxhr = $.ajax({
            // the URL for the request
            url: url,
            success: function (json) {
		window.APT_OPTIONS.gaAjaxEvent(route, method, json.code);
		if (callback !== undefined) {
		    callback(json);
		}
	    },
	    error: function (jqXHR, textStatus, errorThrown) {
		if (callback !== undefined) {
		    callback(networkError);
		}
	    },
 
            // the data to send (will be converted to a query string)
            data: {
		ajax_route:     route,
		ajax_method:    method,
		ajax_args:      args,
            },
 
            // whether this is a POST or GET request
            type: "GET",
 
            // the type of data we expect back
            dataType : datatype,
	});
	var defer = $.Deferred();
    
	jqxhr.done(function (data) {
	    defer.resolve(data);
	});
	jqxhr.fail(function (jqXHR, textStatus, errorThrown) {
	    networkError["jqXHR"] = jqXHR;
	    defer.resolve(networkError);
	});
	return defer;
    }

    // Easier to get a binary (gzip) file this way, since jquery does
    // not directly support doing this. 
    function GetBlob(url, success, failure) {
	var oReq = new XMLHttpRequest();
	oReq.open("GET", url, true);
	oReq.responseType = "arraybuffer";

	oReq.onload = function(oEvent) {
	    success(oReq.response)
	};
	oReq.onerror = function(oEvent) {
	    failure();
	};
	oReq.send();
    }

    /*
     * Saving this. It is faster to go directly to the aggregate, but
     * they all have to have valid certificates. Note that we cannot load
     * it via http from inside an https page, the browser will block it.
     */
    function SaveMe(args) {
	console.info("ShowFrequencyGraph", args);
	GetBlob(window.URL + ".gz",
		function (arrayBuffer) {
		    console.info("gz version");
		    var output = pako.inflate(arrayBuffer, { 'to': 'string' });
		    
		    var data = d3.csvParse(output, type);
		    CreateBinGraph(args, data);
		},
		function () {
		    $.get(window.URL)
			.done(function (data) {
			    console.info("text version");
			    data = d3.csvParse(data, type);
			    CreateBinGraph(args, data);
			})
			.fail(function() {
			    alert("Could not get data file: " + window.URL);
			});
		});
    }

    function getRandomInt() {
	var min = 10000;
	var max = 99999999;
	
	return Math.floor(Math.random() * (max - min + 1)) + min;
    }

    // Link to the graph page for a specific graph.
    function GraphURL(args, info)
    {
	if (_.has(info, "graphurl")) {
	    return info.graphurl;
	}
	var dirname = info["dirname"];
	
	var url = window.location.origin + "/" +
	    window.location.pathname + "?logid=" + info.logid +
	    "&node_id=" + info.node_id +
	    "&iface=" + info.iface;

	if (args.cluster) {
	    url = url + "&cluster=" + args.cluster;
	}
	if (args.baseline) {
	    url = url + "&baseline=1";
	    
	    if (!args.cluster) {
		url = url + "&cluster=" + dirname;
	    }
	}
	else if (dirname == "archive") {
	    url = url + "&archived=1";
	}
	// Remember it so we can add a link at top of page when selected
	info["graphurl"] = url;
	return url;
    }

    function BuildMenu(args)
    {
	// the graph we want to display (if specified).
	var display = null;
	var latest  = null;
	// nuc2:rf0-1588699912.csv.gz
	var re1 = /([^:]+):([^\-]+)\-(\d+)\.csv\.gz/;

	// Process the returned list of files and directories.
	var processDir = function (path, dirname, dirlist) {
	    var path = path + "/" + dirname;
	    console.info(path, dirname, dirlist);
	    
	    // Prune the csb files then sort them by the timestamp
	    var files   = [];
	    // Directories go at the top.
	    var dirs    = [];
	    // If more then one node, then a directory for each node.
	    var nodes   = {};
	    
	    _.each(dirlist, function(info, index) {
		var name    = info.name;
		var logid   = null;
		var match   = name.match(re1);
		var node_id = null;

		// Process a subdir.
		if (_.has(info, "subdir")) {
		    if (_.size(info.subdir)) {
			var menu = processDir(path, info.name, info.subdir);
			if (_.size(menu)) {
			    info.submenu = menu;
			    dirs.push(info);
			}
		    }
		    return;
		}
		//console.info(name, match);
		if (!match) {
		    return;
		}
		// Prune out other radios and interfaces unless browsing
		if (args.baseline) {
		    info["node_id"] = node_id = match[1];
		    info["iface"]   = match[2];
		}
		else {
		    if ((args.node_id && match[1] != args.node_id) ||
			(args.iface && match[2] != args.iface)) {
			return;
		    }
		    info["node_id"] = node_id = match[1];
		    info["iface"]   = match[2];
		}
		info["path"]      = path;
		info["logid"]     = parseInt(match[3]);
		info["id"]        = getRandomInt();
		info["lastmod"]   = parseInt(info["lastmod"]);
		info["archived"]  = dirname == "archive" ? 1 : 0;

		if (!_.has(nodes, node_id)) {
		    nodes[node_id] = [];
		}
		nodes[node_id].push(info);
	    });
	    if (! (_.size(nodes) || _.size(dirs))) {
		return;
	    }
	    // Build the menu for this level. Directories first.
	    var menu = $("<ul class='dropdown-menu'></ul>");
	    
	    // Directories alphabetically.
	    if (_.size(dirs)) {
		dirs.sort(function (a, b) {
		    if (a.name < b.name) {return -1;}
		    if (a.name > b.name) {return 1;}		    
		    return 0;
		});
		_.each(dirs, function(info) {
		    var item =
			$("<li class='multilevel-menu-parent'>" +
			  "  <a href='#'>" + info.name + "</a>" +
			  "  <div class='multilevel-menu-wrapper dropdown'>" +
			  "  </div> " +
			  "</li>");
		    $(item).find("div").append(info.submenu);
		    $(menu).append(item);
		});
	    }
	    // Sort and build a list for each node. Might be only one node.
	    _.each(nodes, function(list, node_id) {
		var menuitems = [];

		// Sort files by timestamp.
		list.sort(function (a, b) {
		    var atime = (a.logid ? a.logid : a.lastmod);
		    var btime = (b.logid ? b.logid : b.lastmod);

		    return btime - atime;
		});
		_.each(list, function(info) {
		    // Remeber this for generating graph url.
		    info["dirname"] = dirname;
		    
		    var html =
			"<li class='fgraph-" + info.id  + "'>" +
			" <a href='#'>" +
			info.node_id + ":" + info.iface + " - " +
			moment(info.logid ?
			       info.logid : info.lastmod, "X").format("L LTS") +
			"</a></li>";
		    var item = $(html);
		    $(item).click(function (event) {
			event.preventDefault();
			UpdateGraph(args, info);
		    });
		    // Lazily put in the href for the specific graph link.
		    $(item).hover(function (event) {
			var url = GraphURL(args, info);
			$(this).find("a").attr("href", url);
		    });
		    menuitems.push(item);

		    // Watch for the one we want to display.
		    if (args.logid) {
			if (info.logid == args.logid &&
			    info.node_id == args.node_id &&
			    info.iface == args.iface) {
			    display = info;
			}
		    }
		    // Latest graph will be shown if nothing else.
		    if (dirname != "archive" && 
			(!latest || info.latest > latest.logid)) {
			latest = info;
		    }
		});
		if (_.size(nodes) > 1) {
		    var item =
			$("<li class='multilevel-menu-parent'>" +
			  "  <a href='#'>" + node_id + "</a>" +
			  "  <div class='multilevel-menu-wrapper dropdown'>" +
			  "   <ul class='dropdown-menu'>" +
			  "     <li class='disabled text-center'>" +
			  "       <a href='#'>" + node_id + "</a></li>" +
			  "     <li class='divider' role='separator' " +
			  "         style='margin-top: 0;'>" +
			  "   </ul> " +
			  "  </div> " +
			  "</li>");
		    
		    $(item).find("ul").append(menuitems);
		    $(menu).append(item);
		}
		else {
		    $(menu).append(menuitems);
		}
	    });

	    //console.info(dirname, $(menu).html());
	    return menu;
	}
	
	var callback = function (value) {
	    // XXX This will always be a string. Need to
	    // figure out how to deal with errors.
	    if (typeof(value) == "object") {
		console.info("Could not get listing data: " + value.value);
		return;
	    }
	    var listing = JSON.parse(_.unescape(value));

	    var menu = processDir("", "", listing);
	    //console.info($(menu).html());
	    $(args.selector + ' .multilevel-menu').append(menu);

	    $(menu).find(".multilevel-menu-parent")
		.hover(
		    function(event) {
			// Offset of this menu item.
			var offset  = $(this).offset();
			// Offset of the menu.
			var poffset = $(this).closest(".dropdown-menu").offset();
			// Wrapper
			var wrapper = $(this).children(".dropdown");
			// Menu to be displayed
			var menu    = $(wrapper).children(".dropdown-menu");
		    
			console.info(offset, poffset);

			// Adjust the top of the menu.
			var height = $(menu).height();
			var top    = offset.top - poffset.top - 15;
			console.info(height, top);
			$(wrapper).css("top", top + "px");

			// Adjust the left offset of the menu. Oddly, it has to
			// to the left of the scrollbar or else the hover does
			// not work.
			var thiswidth = $(this).width();
			var menuwidth = $(menu).width();
			var left;
		    
			// Clear it so calculation below works right.
			$(wrapper).css("left", '')

			if (poffset.left + thiswidth + menuwidth + 30 >
			    $(window).width()) {
			    var left = 0 - menuwidth;      
			}
			else {
			    left = thiswidth;
			}
			console.info("left", poffset.left, thiswidth, menuwidth,
				     $(window).width(), left);
			$(wrapper).css("left", left + "px")
		    },
		    function(event) {
			var menu = $(event.target)
			    .parent().find(".dropdown-menu");
		    });
	    
	    if (display || latest) {
		UpdateGraph(args, display ? display : latest);
	    }
	    else {
		$(args.selector + " .frequency-graph-maingraph .spinner center")
		    .html("Please select a graph to view");
	    }
	};
	var url = args.url;
	if (args.baseline) {
	    url = url + "/rfbaseline/";
	    if (args.cluster) {
		url = url + args.cluster + "/";
	    }
	}
	else {
	    url = url + "/rfmonitor/";
	}
	url = url + "/listing.php";
	console.info("BuildMenu", url);
	
	$.get(url, callback);
    }

    /*
     * Setup the download button to download the CSV data as a file.
     */
    function SetupDownloadOld(args, csvdata)
    {
	var selector = args.selector + " .download-button";
	var filename = args.node_id + ":" + args.iface +
	    (args.logid ? "-" + args.logid : "") + ".csv";

	console.info("Download", args, filename);
	$(selector)
	    .unbind("click")
	    .removeAttr("disabled")
	    .click(function (event) {
		event.preventDefault();
	    
		var blob     = new Blob([csvdata], {type: 'text/csv'});
		const fileStream = streamSaver.createWriteStream(filename, {
		    size: blob.size 
		});
		
		var readableStream;
		if (0) {
		    readableStream = blob.stream();
		}
		else {
		    readableStream = new Response(Blob).body;
		}

		// more optimized pipe version
		// (Safari may have pipeTo but it's useless
		//   without the WritableStream)
		if (window.WritableStream && readableStream.pipeTo) {
		    return readableStream.pipeTo(fileStream)
			.then(() => console.log('done writing'));
		}
		// Write (pipe) manually
		window.writer = fileStream.getWriter();
		
		const reader = readableStream.getReader();
		
		const pump = () => reader.read()
		    .then(res => res.done
			  ? writer.close()
			  : writer.write(res.value).then(pump));

		pump();
	    });
    }

    function SetupDownload(args, url)
    {
	console.info("Download", url);
	var selector = args.selector + " .download-button";

	$(selector)
	    .attr("href", url)
	    .removeAttr("disabled");
    }

    function SetGraphDetails(args, info)
    {
	// If no logid (timestamp) use the lastmod from the listing.
	var when = (info.logid ? info.logid : info.lastmod);
		    
	$(args.selector + " .frequency-graph-date")
	    .html(moment(when, "X").format("L LTS"))
	    .removeClass("hidden");

	$(args.selector + " .frequency-graph-nodeid")
	    .html(info.node_id);

	$(args.selector + " .frequency-graph-iface")
	    .html(info.iface);

	if (args.cluster) {
	    $(args.selector + " .frequency-graph-cluster")
		.html(args.cluster);
	}
	else if (_.has(info, "path")) {
	    $(args.selector + " .frequency-graph-cluster")
		.html(info.path.split('/').reverse()[0]);
	}

	$(args.selector + ' .moregraphs-dropdown')
	    .find(".active").removeClass("active");
	$(args.selector + ' .moregraphs-dropdown')
	    .find(".fgraph-" + info.id).addClass("active");

	// Link to graph.
	var url = GraphURL(args, info);
	console.info(url);
	
	$(args.selector + ' .share-button')
	    .data("graphurl", url)
	    .removeAttr("disabled");
    }

    function UpdateGraph(args, info)
    {
	/*
	 * It is a little difficult to get binary data, not directly
	 * possible with jquery ajax call, so we have to something
	 * special.
	 */
	var url = args.url;
	if (args.baseline) {
	    url = url + "/rfbaseline/";
	    if (args.cluster) {
		url = url + args.cluster + "/";
	    }
	    url = url + info["path"] + "/";
	}
	else {
	    url = url + "/rfmonitor/";
	    
	    if (info.archived) {
		url = url + "/archive/";
	    }
	}
	url = url + info.node_id + ":" + info.iface;
	if (info.logid) {
	    url = url + "-" + info.logid;
	}
	url = url + ".csv.gz";
			   
	console.info("UpdateGraph", args, info, url);

	// Disable the download button until we have the data.
	$(args.selector + " .download-button").attr("disabled", "disabled");

	// Clear the graph now and show the spinner.	
	$(args.selector + " .frequency-graph-maingraph").html("");
	$(args.selector + " .frequency-graph-subgraph").html("");

	// Throw in the spinner
	var spinner = $(args.selector + " .spinner").clone();
	$(spinner).removeClass("hidden");
	$(args.selector + " .frequency-graph-maingraph").append(spinner);

	GetBlob(url,
		function (arrayBuffer) {
		    console.info("gz version");
		    var output = pako.inflate(arrayBuffer, { 'to': 'string' });
		    
		    var data = d3.csvParse(output, type);
		    CreateBinGraph(args, data);
		    $(args.selector + " .spinner").addClass("hidden");
		    SetupDownload(args, url);
		    SetGraphDetails(args, info);
		},
		function () {
		    alert("Could not get data file: " + url);
		});
    }

    /*
     * Handle the Share button popup.
     */
    function Share(args)
    {
	var selector = args.selector + ' .share-button';
	var url = $(selector).data("graphurl");
	var id = "xxxyyy";
	var input = id + "-url-input";
	var copy  = id + "-url-copy";
	
	var popupstring = 
	    "<div style='width 100%'> "+
	    "  <input readonly type=text " +
	    "       id='" + input + "' " +
	    "       style='display:inline; width: 93%; padding: 2px;' " +
	    "       class='form-control input-sm' " +
	    "       value='" + url + "'>" +
	    "  <a href='#' class='btn' " +
	    "     id='" + copy + "' " +
	    "     style='padding: 0px'>" +
	    "    <span class='glyphicon glyphicon-copy'></span></a></div>";
	
	if ($("#" + input).length == 0) {
	    $(selector).popover({
		html:     true,
		content:  popupstring,
		trigger:  'manual',
		placement:'auto',
		container:'body',
	    });
	    $(selector).popover('show');
	    $('#' + copy).click(function (e) {
		e.preventDefault();
		$('#' + input).select();
		document.execCommand("copy");
		$(selector).popover('destroy');
	    });
	    $('#' + input).click(function (e) {
		e.preventDefault();
		$(selector).popover('destroy');
	    });
	}
	else {
	    $(selector).popover('destroy');
	}
    }

    return function(args) {
	$(args.selector + ' .share-button').click(function (e) {
	    Share(args);
	});
	BuildMenu(args);
    };
}
)();
});
