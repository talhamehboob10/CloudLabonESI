$(function ()
{
    'use strict';

    var template_list   = ["resinfo", "resinfo-totals", "reservation-graph",
			   "range-list", "oops-modal", "waitwait-modal",
			   "visavail-graph"];
    var templates       = APT_OPTIONS.fetchTemplateList(template_list);    
    var oopsString      = templates["oops-modal"];
    var waitwaitString  = templates["waitwait-modal"];
    var mainTemplate    = _.template(templates["resinfo"]);
    var graphTemplate   = _.template(templates["reservation-graph"]);
    var totalsTemplate  = _.template(templates["resinfo-totals"]);
    var rangeTemplate   = _.template(templates["range-list"]);
    var visTemplate     = _.template(templates["visavail-graph"]);
    var amlist          = null;
    var FEs             = {};  // Powder
    var radioinfo       = {};  // Powder
    var matrixinfo      = {};  // Powder
    var isadmin         = false;

    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);

	window.CHARTS = {};

	isadmin  = window.ISADMIN;
	amlist   = JSON.parse(_.unescape($('#amlist-json')[0].textContent));
	console.info("amlist", amlist);
	if (window.ISPOWDER) {
	    radioinfo = JSON.parse(
		_.unescape($('#radioinfo-json')[0].textContent));
	    console.info("radioinfo", radioinfo);
	    
	    matrixinfo = JSON.parse(
		_.unescape($('#matrixinfo-json')[0].textContent));
	    console.info("matrixinfo", matrixinfo);
	}
	GeneratePageBody();

	// Now we can do this. 
	$('#oops_div').html(oopsString);	
	$('#waitwait_div').html(waitwaitString);

	// Give this a slight delay so that the spinners appear.
	// Not really sure why they do not.
	setTimeout(function () {
	    LoadReservations();
	    if (window.ISPOWDER) {
		LoadRangeReservations();
	    }
	}, 100);	
    }

    //
    function GeneratePageBody()
    {
	// Generate the template.
	var html = mainTemplate({
	    amlist:		amlist,
	    isadmin:		isadmin,
	    matrixinfo:         matrixinfo,
	});
	$('#main-body').html(html);
	// Per clusters rows filled in with templates.

	/*
	 * Powder is a special arrangement of graphs.
	 */
	if (window,ISPOWDER) {
	    $('#powder-radios .graph-panel')
		.html(visTemplate({
		    "title" : "Powder Outdoor Radio Availability",
		    "id"    : "radio",
		}))
		.find(".panel").removeClass("hidden");
	    $('#powder-radios .counts-panel')
		.html(totalsTemplate({"title" : "Radios"}));
	    $('#powder-radios .counts-panel .tablesorter')
		.tablesorter({
		    theme : 'bootstrap',
		    widgets : [ "uitheme", "zebra"],
		    headerTemplate : '{content} {icon}',
		});

	    $('#powder-mmimo .graph-panel')
		.html(visTemplate({
		    "title" : "RENEW Massive MIMO Radio Availability",
		    "id"    : "mmimo",
		}))
		.find(".panel").removeClass("hidden");
	    $('#powder-mmimo .counts-panel')
		.html(totalsTemplate({"title" : "Massive MIMO"}));
	    $('#powder-mmimo .counts-panel .tablesorter')
		.tablesorter({
		    theme : 'bootstrap',
		    widgets : [ "uitheme", "zebra"],
		    headerTemplate : '{content} {icon}',
		});

	    $('#powder-ota .graph-panel')
		.html(visTemplate({
		    "title" : "Indoor OTA Lab",
		    "id"    : "ota",
		}))
		.find(".panel").removeClass("hidden");
	    $('#powder-ota .counts-panel')
		.html(totalsTemplate({"title" : "Indoor OTA Lab"}));
	    $('#powder-ota .counts-panel .tablesorter')
		.tablesorter({
		    theme : 'bootstrap',
		    widgets : [ "uitheme", "zebra"],
		    headerTemplate : '{content} {icon}',
		});

	    $('#powder-paired .graph-panel')
		.html(visTemplate({
		    "title" : "Paired Radio Workbenches",
		    "id"    : "paired",
		}))
		.find(".panel").removeClass("hidden");
	    $('#powder-paired .counts-panel')
		.html(totalsTemplate({"title" : "Paired Radio Workbenches"}));
	    $('#powder-paired .counts-panel .tablesorter')
		.tablesorter({
		    theme : 'bootstrap',
		    widgets : [ "uitheme", "zebra"],
		    headerTemplate : '{content} {icon}',
		});

	    $('#powder-servers .counts-panel')
		.html(totalsTemplate({"title" : "Servers"}));
	    $('#powder-servers .counts-panel .tablesorter')
		.tablesorter({
		    theme : 'bootstrap',
		    widgets : [ "uitheme", "zebra"],
		    headerTemplate : '{content} {icon}',
		});
  	    $('#powder-servers .resgraph-panel')
		.html(graphTemplate({
		    "graphid"        : "resgraph-powder-servers",
		    "title"          : "Powder Server",
		    "urn"            : window.EMULABURN,
		    "showhelp"       : true,
		    "showfullscreen" : false
		}));

	    $('#powder-matrix .graph-panel')
		.html(visTemplate({
		    "title" : "PhantomNet RF Attenuator Matrix",
		    "id"    : "matrix",
		}))
		.find(".panel").removeClass("hidden");
	    $('#powder-matrix .counts-panel')
		.html(totalsTemplate({"title" : "Attenuator Matrix"}));
	    $('#powder-matrix .counts-panel .tablesorter')
		.tablesorter({
		    theme : 'bootstrap',
		    widgets : [ "uitheme", "zebra"],
		    headerTemplate : '{content} {icon}',
		});
	    $('#powder-matrix .graph-panel .panel-heading .right-side')
		.html("<span class=small> " +
			" <a href='#' " +
			"    data-target='#matrix-connections-modal' " +
			"    data-toggle='modal'>" +
			"  Matrix Connections</a></span>" +
			"");
	}
	_.each(amlist, function (details, urn) {
	    var graphid = 'resgraph-' + details.nickname;

	    if (window.ISPOWDER) {
		// Powder; these go in a combined graph.
		if (details.isFE) {
		    FEs[urn] = details;
		    return;
		}
		// Powder; Emulab was handled above.
		if (details.nickname == "Emulab") {
		    return;
		}
	    }
	    
	    $('#' + details.nickname + " .counts-panel")
		.html(totalsTemplate({"title" : details.nickname}));

	    $('#' + details.nickname + " .counts-panel .tablesorter")
		.tablesorter({
		    theme : 'bootstrap',
		    widgets : [ "uitheme", "zebra"],
		    headerTemplate : '{content} {icon}',
		});

	    $('#' + details.nickname + " .resgraph-panel")
		.html(graphTemplate({
		    "details"        : details,
		    "graphid"        : graphid + "-servers",
		    "title"          : details.nickname,
		    "urn"            : urn,
		    "showhelp"       : true,
		    "showfullscreen" : false
		}));
	});
	if (window.ISPOWDER && _.size(FEs)) {
	    $('#fixed-endpoints .graph-panel')
		.html(visTemplate({
		    "title" : "Fixed Endpoint Availability",
		    "id"    : "FE",
		}))
		.find(".panel").removeClass("hidden");
	    $('#fixed-endpoints .counts-panel')
		.html(totalsTemplate({"title" : "Fixed Endpoints"}));

	    $('#fixed-endpoints .counts-panel .tablesorter')
		.tablesorter({
		    theme : 'bootstrap',
		    widgets : [ "uitheme", "zebra"],
		    headerTemplate : '{content} {icon}',
	    });
	    $('#fixed-endpoints').removeClass("hidden");
	}

	// Handler for the Reservation Graph Help button
	$('.resgraph-help-button').click(function (event) {
	    event.preventDefault();
	    sup.ShowModal('#resgraph-help-modal');
	});

	// This activates the popover subsystem.
	$('[data-toggle="popover"]').popover({
	    trigger: 'hover',
	    container: 'body'
	});
	// This activates the tooltip subsystem.
	$('[data-toggle="tooltip"]').tooltip({
	    placement: 'auto'
	});
    }
    
    /*
     * Load reservation info from each am in the list and generate
     * graphs and tables.
     */
    function LoadReservations()
    {
	_.each(amlist, function(details, urn) {
 	    var callback = function(json) {
		console.log("LoadReservations " + details.nickname, json);
		var graphid = 'resgraph-' + details.nickname;
		var countid = details.nickname + " .counts-panel";

		if (window.ISPOWDER) {
		    // FEs all go into a single graph.
		    if (details.isFE) {
			ProcessFE(urn, json);
			return;
		    }
		    // Emulab handled specially.
		    if (details.nickname == "Emulab") {
			ProcessPowder(urn, json);
			return;
		    }
		}
		// Kill the spinners
		$('#' + details.nickname + ' .resgraph-spinner')
		    .addClass("hidden");

		if (json.code) {
		    console.log("Could not get reservation data for " +
				details.name + ": " + json.value);
		    $('#' + details.nickname + ' .resgraph-error')
			.html(json.value);
		    $('#' + details.nickname + ' .resgraph-error')
			.removeClass("hidden");
		    return;
		}
		var forecast  = FixForecast(json.value.forecast);
		var skiptypes = json.value.prunelist;

		ShowResGraph({"forecast"       : forecast,
			      "selector"       : graphid + "-servers",
			      "foralloc"       : true,
			      "skiptypes"      : skiptypes,
			      "click_callback" : null});
		
		/*
		 * Fill in the counts panel. The first tuple in the forecast
		 * for each type is the immediately available node count.
		 */
		GenerateCountPanel(urn, countid, forecast, skiptypes, false);
	    };
	    var xmlthing = sup.CallServerMethod(null, "reserve",
						"ReservationInfo",
						{"cluster" : details.nickname,
						 "anonymous" : 1});
	    xmlthing.done(callback);
	});
    }

    /*
     * Powder treats Emulab as three difference groups.
     */
    function ProcessPowder(urn, json)
    {
	var details  = amlist[urn];
	var forecast = {};

	// Kill the spinners
	$('[id^=powder-] .resgraph-spinner')
	    .addClass("hidden");

	if (json.code) {
	    console.log("Could not get reservation data for " +
			details.name + ": " + json.value);

	    $('[id^=powder-] .resgraph-error')
		.html(json.value)
		.reemoveClass("hidden");

	    return;
	}
	var forecasts = FixForecast(json.value.forecast);
	var groups = {};
	
	/*
	 * The radio graph consists of individually reservable nodes that
	 * are in the radioinfo object. No others.
	 */
	_.each(forecasts, function (info, key) {
	    if (_.has(radioinfo[urn], key)) {
		if (radioinfo[urn][key].grouping) {
		    var group = radioinfo[urn][key].grouping;
		    if (!_.has(groups, group)) {
			groups[group] = {};
		    }
		    groups[group][key] = info;
		}
		else {
		    forecast[key] = info;
		}
	    }
	});
	ShowNewGraph(forecast, "radio");
	GenerateCountPanel(urn, "powder-radios .counts-panel",
			   forecast, null, true);

	_.each(groups, function (forecast, group) {
	    ShowNewGraph(forecast, group);
	    GenerateCountPanel(urn, "powder-" + group + " .counts-panel",
			       forecast, null, true);
	});

	/*
	 * The matrix graph consists of nodes in the matrixinfo object
	 */
	forecast = {};
	_.each(forecasts, function (info, key) {
	    if (_.has(matrixinfo, key)) {
		forecast[key] = info;
	    }
	});
	ShowNewGraph(forecast, "matrix");
	GenerateCountPanel(urn, "powder-matrix .counts-panel",
			   forecast, null, true);
	
	/*
	 * Servers are everything else.
	 */
	forecast = {};
	_.each(forecasts, function (info, key) {
	    if (! (_.has(matrixinfo, key) ||
		   _.has(radioinfo[urn], key))) {
		forecast[key] = info;
	    }
	});
	var radioskiptypes = {};
	Object.assign(radioskiptypes, json.value.prunelist);
	Object.assign(radioskiptypes, details.radiotypes);
	
	ShowResGraph({"forecast"       : forecast,
		      "selector"       : "resgraph-powder-servers",
		      "foralloc"       : true,
		      "skiptypes"      : radioskiptypes,
		      "showtypes"      : null,
		      "click_callback" : null});
	GenerateCountPanel(urn, "powder-servers .counts-panel",
			   forecast, json.value.prunelist, false);
    }

    function GenerateCountPanel(urn, selector, forecast, skiptypes, asnodes)
    {
	var details = amlist[urn];
	var html    = "";

	// Sort so its consistent.
	var types = Object.keys(forecast).sort();
	var type;
	
	// Each node type
	for (type of types) {
	    // Skip types we do not want to show.
	    if (skiptypes && _.has(skiptypes, type)) {
		continue;
	    }
	    // This is an array of objects.
	    var array = forecast[type];
	    // We want the first stime stamp, but there might be
	    // multiple entries for that time stamp, so scan foward
	    // to find the last one.
	    var data  = array[0];
	    for (var i in array) {
		var datum = array[i];
		if (datum.t == data.t) {
		    data = datum;
		}
	    }
	    var free  = parseInt(data.free) + parseInt(data.held);
	    // Link to the (public) shownode page.
	    var weburl = details.weburl;
	    // Reservable hack.
	    if (_.has(details.reservable_nodes, type)) {
		weburl += "/portal/show-node.php?node_id=" + type;
	    }
	    else {
		weburl += "/portal/show-nodetype.php?type=" + type;
	    }
	    if (details.isFE) {
		type = details.abbreviation + " " + type;
	    }
	    else if (0 && window.ISPOWDER) {
		if (_.has(radioinfo[urn], type) && type.search(/\-/) < 0) {
		    type = radioinfo[urn][type].location + " " + type;
		}
	    }
	    weburl = "<a href='" + weburl + "' target=_blank>" + type + "</a>";

	    // One node, use Yes/No instead of 0/1
	    if (asnodes) {
		free = (free ? "Yes" : "No");
	    }
	    html +=
		"<tr>" +
		" <td>" + weburl + "</td>" +
		" <td>" + free + "</td>" +
		"</tr>";
	}
	$('#' + selector + ' tbody').append(html);
	if (asnodes) {
	    $('#' + selector + ' .type-header').html("Node");
	}
	$('#' + selector + ' table')
	    .removeClass("hidden")
	    .trigger( 'updateAll', [ true, function () {} ] );	
    }

    /*
     * We handle FE forcasts as they return here, so we can create a
     * single combined graph. Note that my original trick of replacing
     * the graph as each one came back, did not work. The NVD3 libraries
     * cannot handle that, they leave all kinds of state behind.
     */
    var FEresults = {};
    
    function ProcessFE(urn, json)
    {
	var details = amlist[urn];
	var combinedForecasts = {};
	var countid = "fixed-endpoints .counts-panel";
	
	if (json.code) {
	    console.log("Could not get reservation data for " +
			details.name + ": " + json.value);
	    FEresults[urn] = null;
	}
	else {
	    FEresults[urn] = json.value;
	}
	// Wait till they all return.
	var keys = Object.keys(FEs);
	for (var i = 0; i < keys.length; i++) {
	    var urn       = keys[i];
	    var details   = amlist[urn];
	    
	    if (details.isFE && !_.has(FEresults, urn)) {
		return;
	    }
	}
	// Kill the spinners.
	$('#fixed-endpoints .resgraph-spinner').addClass("hidden");

	// Combine into a single forecast
	Object.keys(FEs)
	    .sort()
	    .forEach(function(urn, index) {
		// Do we have the forecasts yet?
		if (!FEresults[urn]) {
		    return;
		}
		var forecasts = FixForecast(FEresults[urn].forecast);
		var tmp = {};
		
		Object.keys(forecasts)
		    .sort()
		    .forEach(function(type, index) {
			var forecast = forecasts[type];
			var id = amlist[urn].abbreviation + " " + type;

			tmp[type] = forecast;
			combinedForecasts[id] = forecast;
		    });
		GenerateCountPanel(urn, countid, tmp, null, true);
	    });
	ShowNewGraph(combinedForecasts, "FE");
    }

    /*
     * Generate a new style graph in the provide container.
     */
    function ShowNewGraph(forecasts, tag)
    {
	var dataset = [];
	var now     = new Date();
	var limit   = new Date();
	var maxend  = now;
	var container = tag + "-graph-body";
	var graph     = tag + "-graph-visavail";
	var zoomin  = $('#' + container).closest(".panel")
	    .find(".panel-heading .zoom-control .zoom-in");
	var zoomout = $('#' + container).closest(".panel")
	    .find(".panel-heading .zoom-control .zoom-out");

	// Do not show more then 60 days, the graphs are hard to read.
	limit.setDate(limit.getDate() + 60);
	
	Object.keys(forecasts)
	    .sort()
	    .forEach(function(id, index) {
		var forecast = forecasts[id];
		console.info(id, forecast);

		var series = {
		    "measure"   : id,
		    "interval_s": 3600,
		    "data"      : [],
		    "categories": {
			"Busy": { "color": "black" },
			"Free": { "color": "green"},
			"Pending": { "color": "blue"},
			"Overbook": { "color": "red"},
		    },
		};
		for (var i = 0; i < forecast.length; i++) {
		    var info  = forecast[i];
		    var start = moment(info.stamp).toDate();
		    var state;
		    var end;

		    if (info.free == 1) {
			if (_.has(info, "unapproved") && info.unapproved != 0) {
			    state = "Pending";
			}
			else {
			    state = "Free";
			}
		    }
		    else if (info.free == 0 || !isadmin) {
			state = "Busy"
		    }
		    else {
			state = "Overbook";
		    }
		    if (i < forecast.length - 1) {
			end = moment(forecast[i + 1].stamp).toDate();
		    }
		    else {
			end = new Date(start.getTime());
			end.setMonth(end.getMonth()+2);
		    }
		    // Upper bound on the end of the last entry, so
		    // we can even things out on the very right
		    // side.
		    if (end > maxend) {
			if (end > limit) {
			    end = new Date(limit.valueOf());
			}
			maxend = end;
		    }
		    series.data.push([start, state, end]);
		}
		dataset.push(series);
	    });
	
	// Even out the right side.
	_.each(dataset, function(series) {
	    var last = series.data[series.data.length - 1];
	    var end  = last[2];
	    if (maxend > end) {
		if (!last.free) {
		    last[2] = maxend;
		}
	    }
	});
	console.info("ShowNewGraph", dataset);
	
	var options = {
	    id_div_container: container,
	    id_div_graph: graph,
	    moment_locale: null,
	    line_spacing: 12,
	    custom_categories: true,
	    
	    responsive: {
		enabled: true,
	    },
	    icon: {
		class_has_data: 'fas fa-fw fa-check',
		class_has_no_data: 'fas fa-fw fa-exclamation-circle'
	    },
	    margin: {
		// top margin includes title and legend
		top: 25,
		// right margin should provide space for last horz. axis title
		right: 20,
		bottom: 0,
		// left margin should provide space for y axis titles
		left: 120,
	    },
	    padding:{
		// Match left margin above. Not sure why.
		left: -120
	    },
	    graph:{
		height:12,
	    },
	    tooltip: {
		enabled: true,
		date_plus_time: true,
	    },
	    zoom: {
		enabled: true,
	    },
	    legend: {
		enabled: false,
	    },
	    title: {
		enabled: false,
	    },
	    sub_title: {
		enabled: false,
	    },
	};
	var chart = visavail.generate(options, dataset)

	$(zoomin).click(function (event) {
	    event.preventDefault();
	    chart.zoomin();
	})
	$(zoomout).click(function (event) {
	    event.preventDefault();
	    chart.zoomout();
	})
    }

    //
    // Fix the forecasts 
    //
    function FixForecast(forecast)
    {
	// Each node type
	for (var type in forecast) {
	    // This is an array of objects.
	    var array = forecast[type];

	    for (var i = 0; i < array.length; i++) {
		var data = array[i];
		data.t     = parseInt(data.t);
		data.free  = parseInt(data.free);
		data.held  = parseInt(data.held);
		data.stamp = new Date(parseInt(data.t) * 1000);
		// New
		if (_.has(data, "unapproved")) {
		    data.unapproved = parseInt(data.unapproved);
		}
		else {
		    data.unapproved = 0;
		}
	    }

	    // No data or just one data point, nothing to do.
	    if (array.length <= 1) {
		continue;
	    }
	    
	    /*
	     * Gary says there can be duplicate entries for the same time
	     * stamp, and we want the last one. So have to splice those
	     * out before we process. Yuck.
	     */
	    var temp = [];
	    for (var i = 0; i < array.length - 1; i++) {
		var data     = array[i];
		var nextdata = array[i + 1];
		
		if (data.t == nextdata.t) {
		    continue;
		}
		temp.push(data);
	    }
	    temp.push(array[array.length - 1]);
	    forecast[type] = temp;
	}
	return forecast;
    }

    /*
     * Load the range reservation info.
     */
    function LoadRangeReservations()
    {
	var callback = function(json1, json2) {
	    if (json1.code || json2.code) {
		console.info("Could not get range info");
		return;
	    }
	    if (! (_.size(json1.value) || _.size(json2.value))) {
		return;
	    }
	    var html = rangeTemplate({
		"ranges" : json1.value.concat(json2.value),
	    });
	    $('#range-list').html(html).removeClass("hidden");

	    // Format dates with moment before display.
	    $('#range-list .format-date').each(function() {
		var date = $.trim($(this).html());
		if (date != "") {
		    $(this).html(moment(date).format("lll"));
		}
	    });
	    $('#range-list .tablesorter')
		.tablesorter({
		    theme : 'bootstrap',
		    widgets : [ "uitheme", "zebra"],
		    headerTemplate : '{content} {icon}',
		});
	    if (_.size(json2.value)) {
		$('#range-list .experiment-reserved-ranges')
		    .removeClass("hidden");
	    }
	};

	var xmlthing1 = sup.CallServerMethod(null, "resgroup",
					    "RangeReservations");
	var xmlthing2 = sup.CallServerMethod(null, "rfrange",
					     "AllInuseRanges");
	$.when(xmlthing1, xmlthing2)
	    .done(function(result1, result2) {
		console.info("LoadRangeReservations", result1, result2);
		callback(result1, result2);
	    });
    }
    
    $(document).ready(initialize);
});
