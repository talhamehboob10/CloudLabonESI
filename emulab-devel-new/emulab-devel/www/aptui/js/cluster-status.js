$(function ()
{
    'use strict';

    var templateList = APT_OPTIONS.fetchTemplateList(['cluster-status', 'cluster-status-templates']);
    var mainString = templateList['cluster-status'];
    var templateString = templateList['cluster-status-templates'];
    var isadmin        = 0;
    var mainTemplate   = _.template(mainString);
    var countsTemplate = null;
    var preresTemplate = null;
    var amlist         = null;

    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);
	isadmin = window.ISADMIN || window.ISFADMIN;
	amlist = JSON.parse(_.unescape($('#agglist-json')[0].textContent));
	
	/*
	 * We want things ordered specially in Powder, alphabetic no good. :-(
	 */
	if (window.ISPOWDER) {
	    var ordered = {};
	    if (_.has(amlist, "Emulab")) {
		ordered["Emulab"] = amlist["Emulab"];
		amlist["Emulab"]  = undefined;
	    }
	    _.each(amlist, function (details, nickname) {
		if (details && !(details.isFE || details.isME)) {
		    ordered[nickname] = amlist[nickname];
		    amlist[nickname]  = undefined;
		}
	    });
	    _.each(amlist, function (details, nickname) {
		if (details && details.isFE) {
		    ordered[nickname] = amlist[nickname];
		    amlist[nickname]  = undefined;
		}
	    });
	    _.each(amlist, function (details, nickname) {
		if (details) {
		    ordered[nickname] = amlist[nickname];
		}
	    });
	    amlist = ordered;
	}
	var html = mainTemplate({
	    "amlist"  : amlist,
	    "isadmin" : isadmin,
	});
	$('#page-body').html(html);

	/*
	 * The template file has several different sections inside
	 * script tags. We need to compile each one separately.
	 */
	var html   = $.parseHTML(templateString, document, true);
	countsTemplate = _.template($('#counts-template', html).html());
	preresTemplate = _.template($('#preres-template', html).html());
	LoadData();
    }

    function LoadData()
    {
	_.each(amlist, function(info, name) {
	    var urn = info.urn;
	    var callback = function(json) {
		console.log(json);
		if (json.code) {
		    console.log("Could not get cluster data: " + json.value);
		    $('#cluster-status-' + name + ' .cluster-status-error')
			.html(json.value)
			.removeClass("hidden");
		    $('#cluster-status-' + name + ' .resgraph-spinner')
			.addClass("hidden");
		    return;
		}
		var inuse = json.value.inuse;
		var html = "";

		_.each(inuse, function(value, name) {
		    var type = "";
		    if (_.has(value, "type")) {
			type = value.type;
		    }
		    html = html + "<tr><td>";
		    var url = json.value.url +
			"/portal/show-node.php?node_id=" + value.node_id;
		    html +=
			"<a href='" + url + "' target=_blank>" +
			value.node_id + "</a></td>";
		    html += "<td>" + type + "</td>";

		    if (isadmin) {
			var expires = "";
			if (_.has(value, "ttl")) {
			    var ttl = value.ttl;
			    if (ttl != "") {
				expires = moment()
				    .add(ttl, 'seconds').fromNow();
			    }
			}
			var allowed = "";
			if (_.has(value, "maxttl")) {
			    var maxttl = value.maxttl;
			    if (maxttl != "") {
				allowed = moment()
				    .add(maxttl, 'seconds').fromNow();
			    }
			}
			var uid = "";
			if (_.has(value, "uid")) {
			    uid = value.uid;
			}
			var eid = "";
			if (_.has(value, "eid")) {
			    eid = value.eid;
			    if (_.has(value, "instance_uuid")) {
				var uuid = value.instance_uuid;
				eid = "<a href='status.php?uuid=" + uuid +
				    "' target=_blank>" +
				    value.instance_name + "</a>";
			    }
			    else {
				var url = json.value.url +
				    "/showexp.php3?pid=" + value.pid +
				    "&eid=" + value.eid;
				eid = "<a href='" + url + "' target=_blank>" +
				    value.eid + "</a>";
			    }
			}
			html = html +
			    "<td>" + value.pid + "</td>" +
			    "<td>" + eid + "</td>" +
			    "<td>" + uid + "</td>" +
			    "<td>" + expires + "</td>" +
			    "<td>" + allowed + "</td>" +
			    "<td>" + value.reserved_pid + "</td>";
		    }
		    else {
			if (value.available) {
			    html = html + "<td>Yes</td>";
			}
			else {
			    html = html + "<td>No</td>";
			}
		    }
		    html = html + "</tr>";		    
		});
		$('#' + name + '-tbody').html(html);

		// These are the totals.
		html = countsTemplate({"totals" : json.value.totals,
				       "weburl" : info.url,
				       "isadmin": isadmin});
		$('#counts-panel-' + name).html(html);

		$('#counts-panel-' + name + ' table')
		    .tablesorter({
			theme : 'bootstrap',
			widgets: ["uitheme"],
			headerTemplate : '{content} {icon}',
		    });

		// We reference the totals table in InitTable();
		InitTable(name);
		$('#cluster-status-' + name + ' .resgraph-spinner')
		    .addClass("hidden");

		// This activates the tooltip subsystem.
		$('#counts-panel-' + name + ' ' +
		  '[data-toggle="tooltip"]').tooltip({
		      delay: {"hide" : 500, "show" : 150},
		      placement: 'auto',
		  });		
	    }
	    var xmlthing = sup.CallServerMethod(null, "cluster-status",
						"GetStatus",
						{"cluster" : urn});
	    xmlthing.done(callback);
	});
	if (!isadmin) {
	    return;
	}
	_.each(amlist, function(info, name) {
	    var urn = info.urn;
	    var callback = function(json) {
		console.log(json);
		if (json.code) {
		    console.log("Could not get prereserve data: " + json.value);
		    return;
		}
		if (json.value == null) {
		    return;
		}
		var expando_class  = "expando-" + name;
		
		var html = preresTemplate({
		    "cluster_name"  : name,
		    "expando_class" : expando_class,
		    "prereslist"    : json.value,
		    "moment"        : moment,
		});
		$('#prereserve-panel-' + name).html(html);

		$('#prereserve-panel-' + name + ' table')
		    .tablesorter({
			theme : 'bootstrap',
			widgets: ["uitheme"],
			headerTemplate : '{content} {icon}',
		    });
		/*
		 * Expand/collapse for each prereserve child (hidden) rows.
		 */
		$('.' + expando_class).click(function () {
		    var rowname = $(this).data("target");

		    if (! $(rowname).hasClass("in")) {
			$(rowname).collapse('show');
			$(this).removeClass("glyphicon-chevron-right");
			$(this).addClass("glyphicon-chevron-down");
		    }
		    else {
			$(rowname).collapse('hide');
			$(this).removeClass("glyphicon-chevron-down");
			$(this).addClass("glyphicon-chevron-right");
		    }
		});
		 
		/*
		 * Expand/Collapse the extire prereserve table.
		 */
		$('#prereserve-collapse-button-' + name).click(function () {
		    var panelname = '#prereserve-panel-' + name;

		    if (! $(panelname).hasClass("in")) {
			$(panelname).collapse('show');
			$(this).removeClass("glyphicon-chevron-right");
			$(this).addClass("glyphicon-chevron-down");
		    }
		    else {
			$(panelname).collapse('hide');
			$(this).removeClass("glyphicon-chevron-down");
			$(this).addClass("glyphicon-chevron-right");
		    }
		});
		// Show the panel.
		$('#prereserve-row-' + name).removeClass("hidden");
	    }
	    var xmlthing = sup.CallServerMethod(null, "cluster-status",
						"GetPreReservations",
						{"cluster" : urn});
	    xmlthing.done(callback);
	});
    }

    function InitTable(name)
    {
	var tablename  = "#inuse-table-" + name;
	var searchname = "#inuse-search-" + name;
	var countname  = "#inuse-count-" + name;
	var clickname  = "#inuse-click-" + name;
	var panelname  = "#inuse-panel-" + name;
	
	var table = $(tablename)
		.tablesorter({
		    theme : 'bootstrap',
		    widgets: ["uitheme", "filter"],
		    headerTemplate : '{content} {icon}',

		    widgetOptions: {
			// include child row content while filtering, if true
			filter_childRows  : true,
			// include all columns in the search.
			filter_anyMatch   : true,
			// class name applied to filter row and each input
			filter_cssFilter  : 'form-control input-sm',
			// search from beginning
			filter_startsWith : false,
			// Set this option to false for case sensitive search
			filter_ignoreCase : true,
			// Only one search box.
			filter_columnFilters : true,
			}
		});

	table.bind('filterEnd', function(e, filter) {
	    $(countname).text(filter.filteredRows);
	});

	// Target the $('.search') input using built in functioning
	// this binds to the search using "search" and "keyup"
	// Allows using filter_liveSearch or delayed search &
	// pressing escape to cancel the search
	$.tablesorter.filter.bindSearch(table, $(searchname));
	if (window.ISCLOUD) {
	    $.tablesorter.filter.bindSearch(table, $('#inuse-search-all'));
	}

	/*
	 * This is the expand/collapse button for an individual table.
	 */
	$('#inuse-collapse-button-' + name).click(function (event) {
	    event.preventDefault();
	    
	    if ($(panelname).data("status") == "minimized") {
		$(panelname).removeClass("inuse-panel");
		$('#counts-panel-' + name).removeClass("counts-panel");
		$(panelname).data("status", "maximized");
		$(this).removeClass("glyphicon-chevron-right");
		$(this).addClass("glyphicon-chevron-down");
	    }
	    else {
		$(panelname).addClass("inuse-panel");
		$('#counts-panel-' + name).addClass("counts-panel");
		$(panelname).data("status", "minimized");
		$(this).removeClass("glyphicon-chevron-down");
		$(this).addClass("glyphicon-chevron-right");
	    }
	})
	// Only one, expand immediately.
	if (Object.keys(amlist).length == 1) {
	    $('#inuse-collapse-button-' + name).click();
	}
	$(tablename).removeClass("hidden");

	// Bind type column in the counts table to initiating search
	$('#counts-panel-' + name + ' .counts-search').click(function(event) {
	    event.preventDefault();
	    $(tablename +
	      ' input.tablesorter-filter.form-control[data-column="1"]')
		.val($(this).data("type"));
	    table.trigger('search', false);	    
	});
    }
    
    $(document).ready(initialize);
});
