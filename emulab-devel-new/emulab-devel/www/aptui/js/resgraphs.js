//
// Reservation timeline graph.
//
$(function () {
window.ShowResGraph = (function ()
{
    'use strict';
 
    function ProcessData(args) {
	var forecast = args.forecast;
	// For the availablity page instead of reserve page.
	var foralloc = args.foralloc;
	var unapproved = args.unapproved;
	var skiptypes= args.skiptypes;	
	var showtypes= args.showtypes;	
	var maxdays  = args.maxdays;
	var index    = 0;
	var datums   = [];
	var maxstamp = null;

	if (foralloc === undefined) {
	    foralloc = false;
	}
	if (unapproved === undefined) {
	    unapproved = false;
	}
	if (skiptypes === undefined) {
	    skiptypes = null;
	}
	if (showtypes === undefined) {
	    showtypes = null;
	}
	if (maxdays === undefined) {
	    maxdays = null;
	}
	else {
	    var now = Date.now() / 1000;
	    maxstamp = now + (maxdays * 3600 * 24);
	}

	/*
	 * For the interactive tooltip to work, every has data set has to
	 * have same set of x axis values (timestamps). So we are first
	 * going to create a hash of hashes; the keys are the time stamps
	 * and the value is a hash of type => free for that timestamp.
	 */
	var stamps  = {};

	// Each node type
	for (var type in forecast) {
	    if (skiptypes && _.has(skiptypes, type)) {
		continue;
	    }
	    if (showtypes && !_.has(showtypes, type)) {
		continue;
	    }
	    // This is an array of objects.
	    var array = forecast[type];
	
	    if (array.length == 1) {
		var data = array[0];
		var free = data.free;
		if (foralloc) {
		    free += data.held;
		}
		else if (unapproved && _.has(data, "unapproved")) {
		    free -= data.unapproved;
		    if (free < 0) {
			free = 0;
		    }
		}
		if (free == 0) {
		    continue;
		}
		/*
		 * Need two points to make a line. Give the second point
		 * just a day, we do not want to push the right side of
		 * the graph out too much, we want decent scaling.
		 *
		 * XXX Do not mess with the original array, we want the
		 * original data for popping up the graph in a modal.
		 */
		array = array.slice();
		array.push($.extend({}, data));
		array[1].t = array[1].t +
		    ((maxdays ? maxdays : 45) * 3600 * 24);
	    }
	    else if (array.length > 1) {
		/*
		 * Hmm, Gary says there can be duplicate entries for the same
		 * time stamp, and we want the last one. So have to splice those
		 * out before we process. Yuck.
		 */
		var temp = [];
		for (var i = 0; i < array.length - 1; i++) {
		    var data     = array[i];
		    var nextdata = array[i + 1];

		    if (data.t == nextdata.t) {
			//console.info("toss1", type, data, nextdata);
			continue;
		    }
		    if (!_.has(data, "unapproved")) {
			data["unapproved"] = 0;
		    }
		    if (!_.has(nextdata, "unapproved")) {
			nextdata["unapproved"] = 0;
		    }
		    
		    /*
		     * Oh, turns out two consecutive timestamps can have
		     * the same free/held values. Cull those out too.
		     * We want the first one, eating up the subsequent
		     * timestamps with the same values.
		     */
		    if (data.free == nextdata.free &&
			data.held == nextdata.held &&
			data.unapproved == nextdata.unapproved) {
			//console.info("toss2", type, data);
			temp.push(data);
			for (i = i + 1; i < array.length - 1; i++) {
			    nextdata = array[i];
			    if (! (data.free == nextdata.free &&
				   data.held == nextdata.held &&
				   data.unapproved == nextdata.unapproved)) {
				// Back up for outer loop
				i--;
				break;
			    }
			    //console.info("toss2-B", nextdata);
			}
			continue;
		    }
		    /*
		     * Stop processing after we reach maxdays out. 
		     */
		    if (maxstamp) {
			var t = data.t;
			if (t > maxstamp) {
			    break;
			}
		    }
		    temp.push(data);
		}
		/*
		 * Yuck, after all that we got only one distinct data point!
		 */
		if (temp.length == 0) {
		    /*
		     * As above, generate two points.
		     */
		    var data = $.extend({}, array[0]);
		    data.t = data.t;
		    temp.push(data);
		    temp.push($.extend({}, data));
		    temp[1].t = temp[1].t +
			((maxdays ? maxdays : 45) * 3600 * 24);
		}
		else {
		    // Tack on last one unless it violates maxdays limit.
		    if (temp[temp.length - 1].t != array[array.length - 1].t) {
			var data = array[array.length - 1];
			var t = data.t;

			if (maxstamp && (t > maxstamp)) {
			    // If only one point need to generate another.
			    if (temp.length == 1) {
				data = $.extend({}, data);
				data.t = maxstamp;
				temp.push(data);
			    }
			}
			else {
			    temp.push(data);
			}
		    }
		}
		array = temp;
	    }

	    for (var i = 0; i < array.length; i++) {
		var data  = array[i];
		var stamp = data.t;
		var free  = data.free;
		var avail = free;
		if (foralloc) {
		    free  += data.held;
		    avail += data.held;
		}
		else if (unapproved) {
		    //console.info("a", free, data.unapproved);
		    free -= data.unapproved;
		    if (free < 0) {
			free = 0;
		    }
		}
		//console.info("a'", free);

		if (! _.has(stamps, stamp)) {
		    stamps[stamp] = {};
		}
		stamps[stamp][type] = {
		    "free"  : free,
		    "avail" : avail,
		    "unapproved" : data.unapproved,
		};

		/*
		 * We want the changes to look like step functions not
		 * slopes, so each time we change add another entry for
		 * the previous second with the old free count.
		 */
		if (i > 0) {
		    var lastfree  = array[i - 1].free;
		    var lastavail = lastfree;
		    var lastunapproved = array[i - 1].unapproved;
		    var prevstamp = stamp - 1;
		    if (foralloc) {
			lastfree  += array[i - 1].held;
			lastavail += array[i - 1].held;
		    }
		    else if (unapproved) {
			//console.info("b", lastfree, array[i-1].unapproved);
			lastfree -= lastunapproved;
			if (lastfree < 0) {
			    lastfree = 0;
			}
		    }
		    //console.info("b'", lastfree);
		    if (! _.has(stamps, prevstamp)) {
			stamps[prevstamp] = {};
		    }
		    stamps[prevstamp][type] = {
			"free" : lastfree,
			"avail" : lastavail,
			"unapproved" : lastunapproved,
		    };
		}
	    }
	}
	/*
	 * Well, this can happen; no datapoints cause no reservations
	 * and no experiments.
	 */
	if (Object.keys(stamps).length == 0) {
	    return null;
	}
	
	/*
	 * Create a sorted (by timestamp) array of the per-stamp hashes.
	 */
	var array = Object.keys(stamps).map(function (key) {
	    return {stamp  : parseInt(key),
		    date   : new Date(parseInt(key) * 1000),
		    counts : stamps[key]};
	});
	array = array.sort(function(obj1, obj2) {
	    // Ascending: first stamp less than the previous
	    return obj1.stamp - obj2.stamp;
	});

	/*
	 * Nuts, the first timestamp does not always include all the
	 * types. It should ... so fill those in with the first count
	 * we find in the ordered array.
	 */
	for (var i = 1; i < array.length; i++) {
	    var counts = array[i].counts;

	    // Each node type
	    for (var type in counts) {
		if (!_.has(array[0].counts, type)) {
		    array[0].counts[type] = counts[type];
		}
	    }
	}
	
	// The first array element now has all the types we want to graph.
	var types = Object.keys(array[0].counts);

	// Sort them so they are always in the same order/color.
	types = types.sort();

	/*
	 * Okay, since each time stamp has to have data points for every
	 * type, go through each stamp and fill in the missing values from
	 * the immediately preceeding stamp. All of this to make the
	 * fancy tooltip work right! Sheesh.
	 */
	for (var i = 1; i < array.length; i++) {
	    var counts = array[i].counts;

	    // Each node type
	    for (var t = 0; t < types.length; t++) {
		var type = types[t];
		
		if (!_.has(counts, type)) {
		    counts[type] = array[i - 1].counts[type];
		}
	    }
	}

	/*
	 * Okay, another adjustment. Make sure there is at least one point
	 * on each day.
	 */
	var temp = [];
	for (var i = 0; i < array.length; i++) {
	    var counts    = array[i].counts;
	    var stamp     = array[i].stamp;
	    
	    temp.push(array[i]);

	    if (i < array.length - 1) {
		var nextstamp = array[i + 1].stamp;

		if (nextstamp - stamp > (3600 * 48)) {
		    while (stamp + (3600 * 24) < nextstamp) {
			stamp += (3600 * 24);

			var data = $.extend({}, array[i]);
			data.stamp = stamp;
			data.date  = new Date(stamp * 1000),
			temp.push(data);
		    }
		}
	    }
	}
	// Gack, throw in a padding data point so that it is possible to click
	// at the very right hand side of the graph.
	var data = $.extend({}, array[array.length - 1]);
	data.stamp = data.stamp + (3600 * 24);
	data.date  = new Date(data.stamp * 1000),
	temp.push(data);
	
	array = temp;
	//console.info(array);

	/*
	 * Finally, create the series data for NVD3.
	 */
	for (var t = 0; t < types.length; t++) {
	    var type = types[t];
	    var values = [];
	    
	    datums[index] = {
		"key"    : type,
		"area"   : 0,
		"values" : values,
	    };
	    if (_.has(args, "colors") && _.has(args.colors, type)) {
		datums[index]["color"] = args.colors[type];
	    }
	    index++;

	    for (var i = 0; i < array.length; i++) {
		var stamp  = array[i].stamp;
		var counts = array[i].counts;

		values[i] = {
		    // convert seconds to milliseconds.
		    "x" : stamp * 1000,
		    "y" : counts[type].free,
		    "unapproved" : counts[type].unapproved,
		    "avail" : counts[type].avail,
		};
	    }
	}
	return datums;
    }

    function CreateGraph(datums, args)
    {
	var selector = args.selector;
	var click_callback = args.click_callback;
	var showbrush = args.showbrush;
	var widebrush = args.widebrush;
	var unapproved = args.unapproved;
	var id = '#' + selector;
	$(id + ' svg').html("");

	// New option
	if (showbrush === undefined) {
	    showbrush = true;
	}

	window.nv.addGraph(function() {
	    var chart;

	    if (showbrush) {
		chart  = window.nv.models.lineWithFocusChart();
	    }
	    else {
		chart =  window.nv.models.lineChart();
	    }
	    chart.margin({"left":25,"right":15,"top":20,"bottom":20});
	    
	    /*
	     * We need the min,max of the time stamps for the brush. We can use
	     * just one of the nodes.
	     */
	    var minTime = d3.min(datums[0].values,
				 function (d) { return d.x; });
	    var maxTime = d3.max(datums[0].values,
				 function (d) { return d.x; });
	    // Adjust the brush to the first day.
	    if (!widebrush && maxTime - minTime > (3600 * 24 * 14 * 1000)) {
		maxTime = minTime + (3600 * 24 * 14 * 1000);
	    }
	    if (showbrush) {
		chart.brushExtent([minTime,maxTime]);

		chart.x2Axis.tickFormat(function(d) {
		    return d3.time.format('%m/%d')(new Date(d))
		});
	    }
	    chart.xAxis.tickFormat(function(d) {
		return d3.time.format('%m/%d')(new Date(d))
            });	    

	    var intformater = d3.format(',d');
	    var formatter = function (d) {
		return intformater(d);
	    };
	    chart.yAxis.tickFormat(formatter);
	    chart.useInteractiveGuideline(true);
	    
	    d3.select(id + ' svg')
		.datum(datums)
		.call(chart);

            // set up the tooltip to display full dates
            var tsFormat = d3.time.format('%b %-d, %I:%M%p');
            var tooltip = chart.interactiveLayer.tooltip;
            tooltip.headerFormatter(function (d) {
		return tsFormat(new Date(d));
	    });
            tooltip.valueFormatter(function (d, i, p) {
		//console.info(d, i, p);
		if (!p.data.unapproved || !unapproved) {
		    return d;
		}
		var u = p.data.unapproved;
		var a = p.data.avail;
		if (u > a) {
		    u = a;
		}
		return d + " <span style='color: blue;'>(" + u + ")</span>";
	    });

	    /*
	     * When user clicks in the graph, send the timestamp back
	     * to the caller for changing the form. 
	     */
	    if (click_callback) {
		chart.lines.dispatch.on("elementClick", function(e) {
		    //console.info(e);
		    var type = undefined;
		    // Find the "selected" type (if click near enough).
		    for (var i = 0; i < e.length; i++) {
			if (e[i].selected) {
			    type = e[i].series.key;
			}
		    }
		    click_callback(new Date(e[0].point.x), type);
		});
	    }
	    window.nv.utils.windowResize(chart.update);
	});
    }
    // Pass in forecast info for a single aggregate.
    return function(args) {
	//console.info("ShowResGraph", args);
	
	var datums = ProcessData(args);
	if (datums == null) {
	    return;
	}
	console.info("ShowResGraph", args, datums);
	
	if (_.has(args, "resize") && datums.length > 10) {
	    var id = '#' + args.selector + " .resgraph-size";
	    var height = $(id).innerHeight();

	    $(id).css("height", (height + 200) + "px")
		.css("max-height", (height + 200) + "px");
	}
	else if (_.has(args, "height")) {
	    var id = '#' + args.selector + " .resgraph-size";
	    var height = args.height;

	    $(id).css("height", height).css("max-height", height);
	}
	CreateGraph(datums, args);
    };
}
)();
window.DrawResHistoryGraph = (function ()
{
    return function(args)
    {
	var details = args.details;
	var history = details.history;
	var graphid = args.graphid;
	var xlabel  = false;
	var uvalues = [];
	var pvalues = [];
	var backup  = false;
	var zero    = false;
	var minY    = 99999;
	var maxY    = 0;
	var now     = new Date().getTime();
	
	var i = 0;

	if (_.has(args, "xaxislabel")) {
	    xlabel = args.xaxislabel;
	}

	// Need start/end of the reservation to narrow what we show,
	// since the timeline is going to include stamps before the
	// start of the reservation cause of experiments that span
	// the reservation start time. But no stamps after the end.
	var start  = new Date(details.start).getTime();
	var end    = new Date(details.end).getTime();
	console.info("draw start/end", start, end, details.uuid);

	// Scan past any initial timeline entries that are before the
	// start of the reservation.
	for (i = 0; i < history.length; i++) {
	    var record    = history[i];
	    var stamp     = parseInt(record.t) * 1000;

	    console.info("record", stamp, record);

	    if (stamp > start) {
		if (i == 0) {
		    // If this is the first record, then the reservation
		    // started with zero nodes allocated. Add a zero entry.
		    uvalues.push({"x" : start, "y" : 0});
		    pvalues.push({"x" : start, "y" : 0});
		    minY = 0;
		    zero = true;
		    console.info("added zero entry at ", stamp);
		}
		else {
		    // We skipped some entries. Flag that we want to
		    // add the previous entry at beginning of the res.
		    backup = true;
		    i--;
		    console.info("added backup entry at ", start, stamp, i);
		}
		break;
	    }
	}
	if (i == history.length) {
	    // All the entries are before the start, we need to do the
	    // backup entry as above.
	    backup = true;
	    i--;
	    console.info("added initial backup entry at ", stamp, i);
	}

	for (; i < history.length; i++) {
	    var record    = history[i];
	    var stamp     = parseInt(record.t) * 1000;
	    var reserved  = record.reserved;
	    var allocated = record.allocated;

	    // If this is before or after the reservation, reserved will
	    // be empty. Skip it.
	    if (Array.isArray(reserved)) {
		continue;
	    }
	    
	    var pcount = parseInt(allocated[details.remote_pid][details.type]);
	    // Watch for nothing allocated by the user at this time stamp
	    var ucount = 0;
	    if (_.has(allocated, details.remote_uid)) {
		ucount = parseInt(allocated[details.remote_uid][details.type]);
	    }
	    if (zero) {
		// No slopes, just rectangles please.
		uvalues.push({"x" : stamp - 100, "y" : 0});
		pvalues.push({"x" : stamp - 100, "y" : 0});
		zero = false;
	    }
	    else if (backup) {
		stamp  = start;
		backup = false;
	    }
	    if (i > 0) {
		var prev = history[i - 1];

		if (_.has(prev, "pcount")) {
		    var prevstamp = record.realstamp + (24 * 3600 * 1000);
		    
		    while (prevstamp < stamp - 10000) {
			uvalues.push({"x" : prevstamp, "y" : prev.ucount});
			pvalues.push({"x" : prevstamp, "y" : prev.pcount});
			prevstamp += 24 * 3600 * 1000;
		    }
		    // No slopes, just rectangles please.
		    uvalues.push({"x" : stamp - 100, "y" : prev.ucount});
		    pvalues.push({"x" : stamp - 100, "y" : prev.pcount});
		}
	    }
	    uvalues.push({"x" : stamp, "y" : ucount});
	    pvalues.push({"x" : stamp, "y" : pcount});
	    record["pcount"] = pcount;
	    record["ucount"] = ucount;
	    record["realstamp"] = stamp;

	    /*
	     * Keep track of min/max for altering the Y range below.
	     * Makes the graphs a little easier to read. 
	     */
	    var max = (pcount >= ucount ? pcount : ucount);
	    var min = (pcount <= ucount ? pcount : ucount);
	    if (max > maxY) {
		maxY = max;
	    }
	    if (min < minY) {
		minY = min;
	    }
	}
	// Always want the reservation node count to be the maxY
	// so it is obvious when the user is not using all the nodes.
	if (maxY < details.nodes) {
	    maxY = details.nodes; 
	}
	// We need a point at end so that the X scale is correct. This
	// depends on whether its a current reservation or a historical
	// reservation.
	if (details.deleted) {
	    end = new Date(details.deleted).getTime();
	}
	else if (now < end) {
	    end = now;
	}
	uvalues.push({"x" : end,
		      "y" : uvalues[uvalues.length - 1].y});
	pvalues.push({"x" : end,
		      "y" : pvalues[pvalues.length - 1].y});

	
	var minX = uvalues[0].x;
	var maxX = uvalues[uvalues.length - 1].x;
	var data = [{"key" : "Project", "values" : pvalues, "color" : "green"},
		    {"key" : "User", "values" : uvalues, "color" : "blue"}
		   ];
	console.info("usage datums", data);

	nv.addGraph(function() {
	    var chart = window.nv.models.lineWithFocusChart()
		.useInteractiveGuideline(true)
		.forceY([minY > 0 ? minY - 1 : 0, maxY + 1]);

	    chart.margin({"left":25,"right":15,"top":20,"bottom":40});

	    chart.xAxis.tickFormat(function(d) {
		return d3.time.format('%m/%d')(new Date(d))
            });	    
	    chart.x2Axis.tickFormat(function(d) {
		return d3.time.format('%m/%d')(new Date(d))
	    });
	    
	    chart.yAxis
		.tickFormat(d3.format(',d'));

	    // This draws a dashed line to mark the number of nodes reserved.
	    chart.dispatch.on('renderEnd', function(){
		console.log('render complete');
		var line = d3.select(graphid + ' svg')
		    .append('line')
		    .attr({
			x1: chart.margin().left + chart.xAxis.scale()(minX),
			y1: 30 + chart.yAxis.scale()(details.nodes),
			x2: chart.margin().left + chart.xAxis.scale()(maxX),
			y2: 30 + chart.yAxis.scale()(details.nodes)
		    })
		    .style('stroke-dasharray', '5,5')
		    .style('stroke-width', '2px')
		    .style("stroke", "#000");
	    });

	    if (xlabel) {
		var start = moment(details.start);
		var end   = moment(details.end);

		chart.xAxis.axisLabel(start.format('lll') + " ... " +
				      end.format('lll'));
	    }

            // set up the tooltip to display full dates
            var tsFormat = d3.time.format('%b %-d, %I:%M%p');
            var tooltip = chart.interactiveLayer.tooltip;
            tooltip.headerFormatter(function (d) {
		return tsFormat(new Date(d));
	    });

	    d3.select(graphid + ' svg')
		.datum(data)
		.call(chart);
	    
	    nv.utils.windowResize(chart.update);

	    return chart;
	});
    }
}
)();
});
