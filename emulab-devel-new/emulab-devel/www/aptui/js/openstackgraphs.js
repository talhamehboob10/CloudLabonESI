//
// Slothd graphs
//
$(function () {
window.ShowOpenstackGraphs = (function()
    {
	'use strict';
	var uuid       = null;
	var divID      = null;
	var C_callback = null;
	var refreshID  = null;
	var vmmap      = {};
	var phostdata  = {};
	var counters   = {};
	var counter    = {
	    "network.create" : 0,
	    "network.delete" : 0,
	    "router.create"  : 0,
	    "router.delete"  : 0,
	    "subnet.create"  : 0,
	    "subnet.delete"  : 0
	};

	function LoadOpenstackData()
	{
	    var callback = function(json) {
		sup.HideWaitWait();

		if (json.code) {
		    console.info("Could not get openstack data: " + json.value);
		    C_callback(false);
		    return;
		}
		var openstackdata = JSON.parse(json.value);
		console.info("openstack", openstackdata);

		//
		// Big string ... but do not show the intervals, it is 1000s
		// of lines of boring data. 
		//
		var intervals = openstackdata.intervals;
		delete openstackdata.intervals;
		console.info("intervals", intervals);
		
		var html = "<pre>" +
		    JSON.stringify(openstackdata,null,2) + "</pre>";
	    	$(divID + ' #jsondata').html(html);

		// First get the mapping of VM UUIDs to VM details.
		_.each(openstackdata.info.vms, function(vmlist, hostname) {
		    var index = 0;
		    
		    /*
		     * Per VM arrays of cpu/net on each physical host.
		     */
		    var phost = {
			"cpu"      : [],
			"netin"    : [],
			"netout"   : [],
			"counters" : {},
		    };
		    phostdata[hostname] = phost;
		    
		    _.each(vmlist, function(details, uuid) {
			vmmap[uuid] = details;
			// And the pnode vname/nodeid
			details["hostvname"] =
			    openstackdata.info.host2vname[hostname];
			details["hostpnode"] =
			    openstackdata.info.host2pnode[hostname];
			
			details.cpu = phost.cpu[index] = {
			    "area"   : 0,
			    "key"    : uuid,
			    "values" : [],
			    "data"   : {},
			    "name"   : details.name,
			};
			details.netin = phost.netin[index] = {
			    "area"   : 0,
			    "key"    : uuid,
			    "values" : [],
			    "data"   : {},
			    "name"   : details.name,
			};
			details.netout = phost.netout[index] = {
			    "area"   : 0,
			    "key"    : uuid,
			    "values" : [],
			    "data"   : {},
			    "name"   : details.name,
			};
			index++;
		    });
		});
		console.info("vmmap", vmmap);

		// These are for bar graphs of operational actions.
		_.each(openstackdata.META.periods, function (period) {
		    counters[period.toString()] = $.extend({}, counter);
		});
		// Need these for fixing the data streams. See below.
		var mintime = null;
		var maxtime = null;
		
		_.each(intervals, function(data, time) {
		    _.each(data.cpu_util, function(utildata, hostname) {
			_.each(utildata.vms, function(stamps, uuid) {
			    var cpu = vmmap[uuid].cpu;
			    _.each(stamps, function(stamp, when) {
				if (when == "__FLATTEN__")
				    return;
				when = parseInt(when);
				if (when == NaN)
				    return;
				if (mintime == null)
				    mintime = when;
				if (maxtime == null)
				    maxtime = when;
				if (when < mintime)
				    mintime = when;
				if (when > maxtime)
				    maxtime = when;
				var t = new Date(when * 1000);
				cpu.data[when.toString()] = {
				    // convert seconds to milliseconds.
				    "x" : when * 1000,
				    "y" : stamp.avg,
				    "t" : t.toString(),
				};
			    });
			});
		    });
		    _.each(data["network.outgoing.bytes.rate"],
			   function(utildata, hostname) {
			_.each(utildata.vms, function(stamps, uuid) {
			    var netout = vmmap[uuid].netout;
			    _.each(stamps, function(stamp, when) {
				when = parseInt(when);
				var t = new Date(when * 1000);
				if (when < mintime)
				    mintime = when;
				if (when > maxtime)
				    maxtime = when;
				netout.data[when.toString()] = {
				    // convert seconds to milliseconds.
				    "x" : when * 1000,
				    "y" : stamp.avg,
				    "t" : t.toString(),
				};
			    });
			});
		    });
		    _.each(data["network.incoming.bytes.rate"],
			   function(utildata, hostname) {
			_.each(utildata.vms, function(stamps, uuid) {
			    var netin = vmmap[uuid].netin;
			    _.each(stamps, function(stamp, when) {
				when = parseInt(when);
				var t = new Date(when * 1000);
				if (when < mintime)
				    mintime = when;
				if (when > maxtime)
				    maxtime = when;
				netin.data[when.toString()] = {
				    // convert seconds to milliseconds.
				    "x" : when * 1000,
				    "y" : stamp.avg,
				    "t" : t.toString(),
				};
			    });
			});
		    });
		});
		_.each(openstackdata.periods, function(period, time) {
		    _.each(period, function(data, dataname) {
			if (!_.has(counter, dataname))
			    return;
			_.each(data, function(hostdata, hostname) {
			    counters[time.toString()][dataname]
				+= hostdata.total;
			});
		    });
		});
		var showActivityHandler = function () {
		    $(divID + ' #chart-tabs #activity-tab')
			.off("shown.bs.tab", showActivityHandler);
		    CreateActivityGraph()
		};
		$(divID + ' #chart-tabs #activity-tab')
		    .on("shown.bs.tab", showActivityHandler);
		
		var t = new Date(mintime);
		var t = new Date(maxtime);
		mintime--;
		maxtime++;
		
		/*
		 * Now convert the hashes into D3 values arrays.
		 */
		_.each(phostdata, function(hostdata, hostname) {
		    // We set this if there is anything to graph on phost.
		    // Otherwise, we will not build a tab for it. 
		    var gotdata = 0;
		    
		    _.each(hostdata.cpu, function(obj, i) {
			if (Object.keys(obj.data).length > 2) {
			    obj.values.push({
				"x" : mintime * 1000,
				"y" : NaN,
			    });
			    _.each(obj.data, function (stamp, when) {
				obj.values.push(stamp);
			    });
			    obj.values.push({
				"x" : maxtime * 1000,
				"y" : NaN,
			    });
			    gotdata++;
			}
		    });
		    _.each(hostdata.netin, function(obj, i) {
			if (Object.keys(obj.data).length > 2) {
			    obj.values.push({
				"x" : mintime * 1000,
				"y" : NaN,
			    });
			    _.each(obj.data, function (stamp, when) {
				obj.values.push(stamp);
			    });
			    obj.values.push({
				"x" : maxtime * 1000,
				"y" : NaN,
			    });
			    gotdata++;
			}
		    });
		    _.each(hostdata.netout, function(obj, i) {
			if (Object.keys(obj.data).length > 2) {
			    obj.values.push({
				"x" : mintime * 1000,
				"y" : NaN,
			    });
			    _.each(obj.data, function (stamp, when) {
				obj.values.push(stamp);
			    });
			    obj.values.push({
				"x" : maxtime * 1000,
				"y" : NaN,
			    });
			    gotdata++;
			}
		    });
		    hostdata["gotdata"] = gotdata;
		});
		console.info("phostdata", phostdata);
		$(divID).removeClass("hidden");

		// Remember the name of the first tab so we can expose it.
		var firsttab = null;

		/*
		 * Now create a new tab for each physical host, by cloning
		 * the template and inserting.
		 */
		_.each(phostdata, function(hostdata, hostname) {
		    var thishost = hostname.split('.')[0];
		    var tabname  = 'openstack-' + thishost;

		    // The tab.
		    var html = "<li><a href='#" + tabname +
			"' data-toggle='tab' id='show-" + tabname + "'>" +
			thishost + "</a></li>";

		    // Append to start of tabs
		    $(divID + ' #chart-tabs').prepend(html);

		    // The content div clone of the template
		    var clone = $(divID + ' #template').clone();

		    // Change the ID of the clone so its unique.
		    clone.attr('id', tabname);
		    // The template is hidden.
		    clone.removeClass("hidden");

		    // Add the tab content wrapper to the DOM,
		    $(divID + ' #chart-contents').prepend(clone);

		    // Handler for when the tab is first exposed; D3
		    // cannot draw the graph until it is visible.
		    var showHandler = function () {
			$(divID + ' #chart-tabs #show-' + tabname)
			    .off("shown.bs.tab", showHandler);
			drawPnodeGraphs(hostname, tabname);
		    };
		    $(divID + ' #chart-tabs #show-' + tabname)
			.on("shown.bs.tab", showHandler);

		    if (firsttab === null)
			firsttab = tabname;
		});
		// Expose the first pnode graph so it draws.
		if (firsttab) {
		    $(divID + ' #chart-tabs #show-' + firsttab).tab('show');
		}
	    };
	    sup.ShowWaitWait("We are gathering data from the cluster(s)");
    	    var xmlthing = sup.CallServerMethod(null, "status",
						"OpenstackStats",
						{"uuid" : uuid});
	    xmlthing.done(callback);
	}

	/*
	 * Remove all the tabs/content we added and reload.
	 */
	function reloadOpenstackData()
	{
	    _.each(phostdata, function(hostdata, hostname) {
		var thishost    = hostname.split('.')[0];
		var tabname     = 'openstack-' + thishost;

		$(divID + ' #chart-tabs #show-' + tabname).parent().remove();
		$(divID + ' #chart-contents #' + tabname).remove();
	    });
	    $(divID + ' #chart-contents #activity svg').remove();
	    phostdata = {};
	    counters  = {};
	    LoadOpenstackData();
	}

	function drawPnodeGraphs(hostname, tabname)
	{
	    //console.info("drawPnodeGraphs", hostname, tabname);

	    var cpu    = phostdata[hostname].cpu;
	    var netin  = phostdata[hostname].netin;
	    var netout = phostdata[hostname].netout;
	    var id     = divID + ' #' + tabname;
	    
	    //console.info(tabname, cpu);
	    var chart1 = window.nv.models.lineWithFocusChart();
	    CreateOneGraph(id + ' .cpu svg', chart1, cpu,
			   {"ytype"  : "float",
			    "ylabel" : "Load Average"});
	    //console.info(tabname, netout);
	    var chart2 = window.nv.models.lineWithFocusChart();
	    CreateOneGraph(id + ' .netout svg', chart2, netout,
			   {"ytype"  : "int",
			    "ylabel" : "Network Bytes Sent"});
	    //console.info(tabname, netin);
	    var chart3 = window.nv.models.lineWithFocusChart();
	    CreateOneGraph(id + ' .netin svg', chart3, netin,
			   {"ytype"  : "int",
			    "ylabel" : "Network Bytes Received"});
	}

	function CreateOneGraph(id, chart, datums, args)
	{
	    var ytype  = args.ytype;
	    var ylabel = args.ylabel;

	    //console.info(id, chart,datums,args);
	    
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
	    var UpdateXaxisLabel = function() {
		var extent = chart.brushExtent();
		var min = moment(extent[0]);
		var max = moment(extent[1]);

		chart.xAxis.axisLabel(min.format('lll') + " ... " +
				      max.format('lll'));
		chart.update();
	    };
	    chart.focus.brush.on("brushend", function () {
		UpdateXaxisLabel();
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
	    /*
	     * We use the uuid as the key, since each graph can have
	     * different nodes with the same name (they move around).
	     * Here, we mape them back to the node name.
	     */
	    chart.legend.key(function(d) { return vmmap[d.key].name });
	    
	    d3.select(id)
		.datum(datums)
		.call(chart);

	    UpdateXaxisLabel();

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
		return vmmap[d].name;
	    });
	    tooltip.classes("tooltip-font");
	    window.nv.utils.windowResize(chart.update);

	    return chart;
	}

	function CreateActivityGraph()
	{
	    var datums = [];
	    var id = divID + ' #activity svg';
	    
	    //console.info("counters", counters);

	    _.each(counter, function (ignore, countername) {
		var values = [];

		_.each(counters, function (data, period) {
		    values.push({"x" : period,
				 "y" : data[countername]});
		});
		var datum = {
		    "key"    : countername,
		    "values" : values,
		};
		datums.push(datum);
	    });
	    console.info(datums);
	    
	    var chart = window.nv.models.multiBarChart();

	    chart.showControls(false);
	    chart.color(d3.scale.category20().range());
	    var width = parseInt(d3.select(id).style('width')) - 80;

	    chart.xAxis
		.scale(d3.scale.ordinal()
 	               .rangeRoundBands([0,width], .1)
	               .domain(datums[0].values.map(function(d) {
			   return d.x; })));	    
	    
	    chart.multibar.yScale(d3.scale.sqrt());
            chart.yAxis
		.scale(d3.scale.sqrt())
		.axisLabel("Operation Counts")
		.tickFormat(d3.format(',.0f'));
	    
            d3.select(id)
		.datum(datums)
		.call(chart);
	    
            nv.utils.windowResize(chart.update);

	}

	return function(args) {
	    uuid       = args.uuid;
	    divID      = args.divID;
	    C_callback = args.callback;

	    if (_.has(args, "refreshID")) {
		refreshID = args.refreshID;

		$(refreshID).removeClass("hidden");
		$(refreshID).click(function () {
		    reloadOpenstackData();
		});
	    }
	    LoadOpenstackData();
	}
    }
)();
});
