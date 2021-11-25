//
// Slothd graphs
//
$(function () {
window.ShowIdleGraphs = (function ()
    {
	'use strict';
	var uuid       = null;
	var rawData    = {};
	var nodeMap    = {};
	var loadID     = null;
	var ctrlID     = null;
	var exptID     = null;
	var refreshID  = null;
	var C_callback = null;
	var showWait   = false;
	var EMULAB_NS = "http://www.protogeni.net/resources/rspec/ext/emulab/1";

	/*
	 * Process data for one type (loadav, ctrl, expt) and return it.
	 *
	 * NOTE: This function mostly about converting the json data that
	 * we get from the cluster, into arrays of objects that NVD3 uses
	 * for generating the line graphs.
	 *
	 * If there are multiple streams (MAX, AVERAGE) we store that
	 * inside the NVD3 data objects, it does not care about that. This
	 * make it easy to find and shuffle things when the user clicks on
	 * the radio buttons to switch between the stream types.
	 */
	function ProcessData(which) {
	    var result = [];
	    var index  = 0;

	    var ProcessSite = function(idledata) {
		/*
		 * Array of objects, one per node. But some nodes might not
		 * have any data (main array is zero), so need to skip those.
		 */
		for (var i in idledata) {
		    var obj = idledata[i];
		    var node_id = obj.node_id;

		    //
		    // If idlestats finds no data, the main array is
		    // zero length. Skip. Okay, 1 point is not interesing
		    // either, so lets wait for two data points.
		    //
		    if (obj.main.length < 2) {
			console.info("No idledata for " + node_id);
			continue;
		    }

		    if (which == "load") {
			var datum = {
			    "key"    : node_id,
			    "area"   : 0,
			    "arrays" : {},
			};
			/*
			 * Backwards compat. Flush soon.
			 */
			if (Array.isArray(obj.main)) {
			    obj.main = {"MAX" : obj.main};
			}
			
			for (var type in obj.main) {
			    var loadvalues = [];
			    var array = obj.main[type];
			
			    for (var j = 1; j < array.length; j++) {
				var loads = array[j];

				loadvalues[j - 1] = {
				    // convert seconds to milliseconds.
				    "x" : loads[0] * 1000,
				    "y" : loads[3],
				};
			    }
			    datum.arrays[type] = loadvalues;
			}
			// Default to MAX;
			datum["values"] = datum.arrays["MAX"];
			result[index++] = datum;
			continue;
		    }
		    if (which == "ctrl" || which == "expt") {
			var control_iface = obj.interfaces.ctrl_iface;

			/*
			 * On the expermental networks, we can have
			 * multiple interfaces per nodes, but we want to
			 * aggregate those into a single line for the
			 * node. So we have to create a datum for the node
			 * now, and add the pkt counts to it.
			 */
			var datum = {
			    "key"    : node_id,
			    "area"   : 0,
			    "arrays" : {"MAX" : {"tx"  : [],
						 "rx"  : [],
						 "sum" : []},
					"AVG" : {"tx"  : [],
						 "rx"  : [],
						 "sum" : []},
				       }
			};
			if (Array.isArray(obj.main)) {
			    obj.main = {"MAX" : obj.main};
			}
			
			// Default to MAX,sum in initial graph.
			datum["values"] = datum.arrays["MAX"]["sum"];

			for (var mac in obj.interfaces) {
			    //console.info(mac, obj.interfaces[mac]);

			    if (mac == "ctrl_iface") {
				continue;
			    }
			    var thismac;

			    /*
			     * If we want the control network graph, skip
			     * all interfaces that are not the control net.
			     * Or if we want the expt graph, skip the control
			     * net mac.
			     */
			    if (which == "ctrl") {
				if (mac != control_iface)
				    continue;
				thismac = "ctrl";
			    }
			    else {
				if (mac == control_iface)
				    continue;
				thismac = "expt";
			    }

			    for (var type in obj.interfaces[mac]) {
				var maxavg  = datum.arrays[type];
			    	var values = obj.interfaces[mac][type];

				//console.info(mac,type,values);

				if (! values.length) {
				    //console.info("no info");
				    continue;
				}
				if (maxavg === undefined) {
				    console.info("unknown type", type);
				    continue;
				}

				for (var j = 1; j < values.length; j++) {
				    var netdata = values[j];
				    var x   = netdata[0] * 1000;
				    var rx  = netdata[1];
				    var tx  = netdata[2];
				    var sum = rx + tx;

				    /*
				     * If we already have data points for
				     * this index, add the new data to the
				     * totals. 
				     */
				    var rxitem  = maxavg["rx"][j - 1];
				    var txitem  = maxavg["tx"][j - 1];
				    var sumitem = maxavg["sum"][j - 1];
				    
				    if (rxitem === undefined) {
					// New data points
					rxitem = {
					    "x" : x,
					    "y" : 0,
					    // Samples, for AVG.
					    "samples" : []
					};
					maxavg["rx"][j - 1] = rxitem;

					txitem = {
					    "x" : x,
					    "y" : 0,
					    // Samples, for AVG.
					    "samples" : []
					};
					maxavg["tx"][j - 1] = txitem;

					sumitem = {
					    "x" : x,
					    "y" : 0,
					    // Samples, for AVG.
					    "samples" : []
					};
					maxavg["sum"][j - 1] = sumitem;
				    }
				    
				    if (type == "MAX") {
					txitem.y  += tx;
					rxitem.y  += rx;
					sumitem.y += sum;
				    }
				    else {
					txitem.samples.push(tx);
					rxitem.samples.push(rx);
					sumitem.samples.push(sum);

					var txsum = 0;
					var rxsum = 0;
					var ssum  = 0;
					var ilen  = txitem.samples.length;
					for (var k = 0; k < ilen; k++) {
					    txsum += txitem.samples[k];
					    rxsum += rxitem.samples[k];
					    ssum  += sumitem.samples[k];
					}
					txitem.y  = txsum / ilen;
					rxitem.y  = rxsum / ilen;
					sumitem.y = ssum  / ilen;
				    }
				}
			    }
			}
			/*
			 * If after all that, there is no actual data,
			 * then we do not add the datum to results.
			 */
			if (datum.values.length) {
			    result[index++] = datum;
			}
		    }
		}
	    };
	    _.each(rawData, function(idledata, name) {
		ProcessSite(idledata);
	    });
	    return result;
	}

	function CreateOneGraph(id, which, datums, args) {
	    $(id).removeClass("hidden");
	    $(id + " .collapse").addClass("in");

	    window.nv.addGraph(function() {
		var chart = window.nv.models.lineWithFocusChart();
		CreateIdleChart(id + ' svg', chart, datums, args);

		// Always start with max.
		$(id + ' .maxavg-toggles input[type=radio][value=max]')
		    .prop('checked', true);
		// And sum of packets for the control network.
		if (which == "ctrl" || which == "expt") {
		    $(id + ' .txrx-toggles input[type=radio][value=sum]')
			.prop('checked', true);
		}

		// Two different radios for the control traffic graph.
		if (which == "ctrl" || which == "expt") {
		    $(id + ' .maxavg-toggles input[type=radio], ' +
		      id + ' .txrx-toggles input[type=radio] ')
			.change(function() {
			    var maxavg =
				$(id + ' .maxavg-toggles ' +
				  'input[type=radio]:checked').val();
			    var txrx =
				$(id + ' .txrx-toggles ' +
				  'input[type=radio]:checked').val();

			    //console.info(maxavg, txrx);

			    _.each(datums, function(datum) {
				var values;
				
				if (maxavg == "max") {
				    values = datum.arrays["MAX"];
				    if (txrx != null) {
					values = values[txrx];
				    }
				}
				else {
				    values = datum.arrays["AVG"];
				    if (txrx != null) {
					values = values[txrx];
				    }
				}
				datum.values = values;
			    });
			    //console.info(datums);
			    d3.select(id + ' svg')
				.datum(datums)
				.call(chart);
			});
		}
		else {
		    // Load avg and expt traffic get just max/avg.
		    $(id + ' .maxavg-toggles input[type=radio]')
			.change(function() {
			    var maxavg =
				$(id + ' .maxavg-toggles ' +
				  'input[type=radio]:checked').val();

			    //console.info(maxavg);

			    _.each(datums, function(datum) {
				var values;
				
				if (maxavg == "max") {
				    values = datum.arrays["MAX"];
				}
				else {
				    values = datum.arrays["AVG"];
				}
				if (which == "expt") {
				    values = values["sum"];
				}
				datum.values = values;
			    });
			    //console.info(datums);
			    d3.select(id + ' svg')
				.datum(datums)
				.call(chart);
			});
		}
	    });
	}

	/*
	 * Ask for the manifests so we can map physical names to client ids.
	 */
	function GetManifests()
	{
	    var callback = function(json) {
		if (json.code) {
		    console.info("GetManifests error:", json);
		    return;
		}
		_.each(json.value, function(manifest, aggregate_urn) {
		    var xmlDoc = $.parseXML(manifest);
		    var xml = $(xmlDoc);

		    $(xml).find("node, emulab\\:vhost").each(function() {
			// Only nodes that match the aggregate being processed,
			// since we send the same rspec to every aggregate.
			var manager_urn = $(this).attr("component_manager_id");
			if (!manager_urn.length ||
			    manager_urn != aggregate_urn) {
			    return;
			}
			var client_id = $(this).attr("client_id");
			var vnode     = this.getElementsByTagNameNS(EMULAB_NS,
								    'vnode');
			if (vnode.length) {
			    nodeMap[$(vnode).attr("name")] = client_id;
			}
		    });
		});
	    };
	    var xmlthing = sup.CallServerMethod(null, "status",
						"GetInstanceManifest",
						{"uuid" : uuid});
	    xmlthing.done(callback);
	}

	function LoadIdleData() {
	    var exptTraffic  = [];
	    var ctrlTraffic  = [];
	    var loadavs      = [];

	    // This will be done before we get the data from the cluster.
	    GetManifests();

	    var callback = function(json) {
		if (json.code) {
		    console.info("Failed to get graph data: " + json.value);
		    if (showWait) {
			sup.HideWaitWait(function () {
			    sup.SpitOops("oops",
					 "Could not get idledata: " +
					 json.value);
			});
		    }
		    if (C_callback) {
			C_callback(-1, json);
		    }
		    return;
		}
		//console.info("rpc", json);
		_.each(json.value, function(data, name) {
		    // No data, skip
		    if (data == "") {
			return;
		    }
		    rawData[name] = JSON.parse(data);
		});
		//console.info("raw", rawData);
		
		// No data, tell caller and done.
		if (Object.keys(rawData).length == 0) {
		    if (C_callback) {
			C_callback(0, json);
		    }
		    return;
		}
		var load = ProcessData("load", "avg");
		var ctrl = ProcessData("ctrl", "avg");
		var expt = ProcessData("expt", "avg");
		
		console.info(load);
		console.info(ctrl);
		console.info(expt);

		// We want to tell the caller if there is any actual data
		if (C_callback) {
		    C_callback(load.length + ctrl.length + expt.length);
		}
		if (showWait) {
		    sup.HideWaitWait();
		}

		if (load.length) {
		    if (load.length > 60) {
			var height = $(loadID +" .idlegraph-div")
			    .innerHeight();
			
			$(loadID + " .idlegraph-div")
			    .css("height", (height + 500) + "px")
			    .css("max-height", (height + 500) + "px");
		    }
		    CreateOneGraph(loadID, "load", load,
				   {"ytype"  : "float",
				    "ylabel" : "Unix Load Average"});
		    $(loadID + ' .maxavg-toggles').popover({
			trigger: 'hover',
			placement: 'auto',
			delay : {"hide": 500, "show": 500},
			html: true,
			content: "MAX is the maximum load average " +
			    "during the interval, while AVG is the average "+
			    "load during the interval. The " +
			    "reported interval in the graph is five minutes "+
			    "for the most recent 24 hours, and then every "+
			    "hour after that. During the first 24 hours MAX "+
			    "and AVG will be the same since the interval is "+
			    "so short."
		    });
		}
		if (ctrl.length) {
		    if (ctrl.length > 60) {
			var height = $(ctrlID +" .idlegraph-div")
			    .innerHeight();
			
			$(ctrlID + " .idlegraph-div")
			    .css("height", (height + 500) + "px")
			    .css("max-height", (height + 500) + "px");
		    }
		    CreateOneGraph(ctrlID, "ctrl", ctrl,
				   {"ytype"  : "int",
				    "ylabel" : "Packets Per Second"});

		    $(ctrlID + ' .maxavg-toggles').popover({
			trigger: 'hover',
			placement: 'auto',
			delay : {"hide": 500, "show": 500},
			html: true,
			content: "MAX is the maximum number of packets " +
			    "within the interval, while AVG is the average "+
			    "number of packets in the interval. The " +
			    "reported interval in the graph is five minutes "+
			    "for the most recent 24 hours, and then every "+
			    "hour after that. During the first 24 hours MAX "+
			    "and AVG will be the same since the interval is "+
			    "so short."
		    });
		    $(ctrlID + ' .txrx-toggles').popover({
			trigger: 'hover',
			placement: 'auto',
			delay : {"hide": 500, "show": 500},
			html: true,
			content: "TX is the number of packets sent " +
			    "within the interval, RX is the number of packets "+
			    "received, and SUM is the sum of packets sent " +
			    "and received in the interval. The " +
			    "reported interval in the graph is five minutes "+
			    "for the most recent 24 hours, and then every "+
			    "hour after that."
		    });
		}
		if (expt.length) {
		    if (expt.length > 60) {
			var height = $(exptID +" .idlegraph-div")
			    .innerHeight();
			
			$(exptID + " .idlegraph-div")
			    .css("height", (height + 500) + "px")
			    .css("max-height", (height + 500) + "px");
		    }
		    CreateOneGraph(exptID, "expt", expt,
				   {"ytype"  : "int",
				    "ylabel" : "Packets Per Second"});
		    
		    $(exptID + ' .maxavg-toggles').popover({
			trigger: 'hover',
			placement: 'auto',
			delay : {"hide": 500, "show": 500},
			html: true,
			content: "MAX is the maximum number of packets sent " +
			    "within the interval, while AVG is the average "+
			    "number of packets sent in the interval. The " +
			    "reported interval in the graph is five minutes "+
			    "for the most recent 24 hours, and then every "+
			    "hour after that. During the first 24 hours MAX "+
			    "and AVG will be the same since the interval is "+
			    "so short."
		    });
		    $(exptID + ' .txrx-toggles').popover({
			trigger: 'hover',
			placement: 'auto',
			delay : {"hide": 500, "show": 500},
			html: true,
			content: "TX is the number of packets sent " +
			    "within the interval, RX is the number of packets "+
			    "received, and SUM is the sum of packets sent " +
			    "and received in the interval. The " +
			    "reported interval in the graph is five minutes "+
			    "for the most recent 24 hours, and then every "+
			    "hour after that."
		    });
		}
	    };
	    if (showWait) {
		sup.ShowWaitWait("We are gathering data from the cluster(s)");
	    }
	    var xmlthing = sup.CallServerMethod(null, "status", "IdleData",
						{"uuid" : uuid});
	    xmlthing.done(callback);	
	}

	function UpdateXaxisLabel(chart) {
	    var extent = chart.brushExtent();
	    var min = moment(extent[0]);
	    var max = moment(extent[1]);

	    chart.xAxis.axisLabel(min.format('lll') + " ... " +
				  max.format('lll'));
	    chart.update();
	}

	function CreateIdleChart(id, chart, datums, args) {
	    var ytype  = args.ytype;
	    var ylabel = args.ylabel;
	    
            var tickMultiFormat = d3.time.format.multi([
		// not the beginning of the hour
		["%-I:%M%p", function(d) { return d.getMinutes(); }],
		// not midnight
		["%-I%p", function(d) { return d.getHours(); }],
		// not the first of the month
		["%b %-d", function(d) { return d.getDate() != 1; }],
		// not Jan 1st
		["%b %-d", function(d) { return d.getMonth(); }], 
		["%Y", function() { return true; }]
            ]);
	    /*
	     * We need the min,max of the time stamps for the brush. We can use
	     * just one of the nodes.
	     */ 
	    var minTime = d3.min(datums[0].values,
				 function (d) { return d.x; });
	    var maxTime = d3.max(datums[0].values,
				 function (d) { return d.x; });
	    // Adjust the brush to the last day.
	    if (maxTime - minTime > (3600 * 24 * 1000)) {
		minTime = maxTime - (3600 * 24 * 1000);
	    }
	    chart.brushExtent([minTime,maxTime]);

	    // Update the display on the X axis after brush change.
	    chart.focus.dispatch.on("brushEnd", function () {
		UpdateXaxisLabel(chart);
	    });

	    // We want different Y axis scales, wow this took a long time
	    // to figure out.
	    chart.lines.scatter.yScale(d3.scale.sqrt());
	    chart.yAxis.scale(d3.scale.sqrt());
	    chart.yAxis.axisLabel(ylabel);

	    chart.xAxis.tickFormat(function (d) {
		return tickMultiFormat(new Date(d));
	    });
	    chart.x2Axis.tickFormat(function (d) {
		return tickMultiFormat(new Date(d));
	    });
	    if (ytype == "float") {
		chart.yAxis.tickFormat(d3.format(',.2f'));
		chart.y2Axis.tickFormat(d3.format(',.2f'));
	    }
	    else {
		var intformater = d3.format(',.0f');
		var floatformater = d3.format(',.2f');
		var formatter = function (d) {
		    if (d < 1.0) {
			return floatformater(d);
		    }
		    else {
			return intformater(d);
		    }
		}
		chart.yAxis.tickFormat(formatter)
		chart.y2Axis.tickFormat(formatter);
	    }
	    chart.useInteractiveGuideline(true);
	    d3.select(id)
		.datum(datums)
		.call(chart);

	    UpdateXaxisLabel(chart);

            // set up the tooltip to display full dates
            var tsFormat = d3.time.format('%b %-d, %Y %I:%M%p');
            var contentGenerator =
		chart.interactiveLayer.tooltip.contentGenerator();
            var tooltip = chart.interactiveLayer.tooltip;
            tooltip.contentGenerator(function (d) {
		d.value = d.series[0].data.x; return contentGenerator(d);
	    });
            tooltip.headerFormatter(function (d) {
		return tsFormat(new Date(d));
	    });
            tooltip.keyFormatter(function (d) {
		return d + " (" + nodeMap[d] + ")";
	    });
	    
	    tooltip.classes("tooltip-font");
	    window.nv.utils.windowResize(chart.update);

	    return chart;
	}

	return function(args) {
	    uuid       = args.uuid;
	    loadID     = args.loadID;
	    ctrlID     = args.ctrlID;
	    exptID     = args.exptID;
	    C_callback = args.callback;
	    showWait   = args.showwait;
	    if (_.has(args, "refreshID")) {
		refreshID = args.refreshID;

		$(refreshID).removeClass("hidden");
		$(refreshID).click(function () {
		    d3.selectAll(loadID + " svg > *").remove();
		    d3.selectAll(ctrlID + " svg > *").remove();
		    d3.selectAll(exptID + " svg > *").remove();
		    LoadIdleData();
		});
	    }
	    LoadIdleData();
	}
    }
)();
});
