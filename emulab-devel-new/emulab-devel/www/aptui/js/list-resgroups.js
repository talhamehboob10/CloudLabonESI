$(function ()
{
    'use strict';

    var mainTemplate;
    var listTemplate;
    var bytypeTemplate;
    var byrangeTemplate;
    var byrouteTemplate;

    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);

	var template_list   = ["list-resgroups", "resgroup-list",
			       "resgroup-list-bytype", "resgroup-list-byrange",
			       "resgroup-list-byroute",
			       "oops-modal", "waitwait-modal"];
	var templates       = APT_OPTIONS.fetchTemplateList(template_list);
	
	mainTemplate    = _.template(templates["list-resgroups"]);
	listTemplate    = _.template(templates["resgroup-list"]);
	bytypeTemplate  = _.template(templates["resgroup-list-bytype"]);
	byrangeTemplate = _.template(templates["resgroup-list-byrange"]);
	byrouteTemplate = _.template(templates["resgroup-list-byroute"]);

	$('#main-body').html(mainTemplate({}));
	$('#oops_div').html(templates["oops-modal"]);	
	$('#waitwait_div').html(templates["waitwait-modal"]);

	sup.CallServerMethod(null, "resgroup", "ListReservationGroups", null,
			     function (json) {
				 if (json.code) {
				     sup.SpitOops("oops", json.value);
				     return;
				 }
				 DoReservations('#groups', json.value);
			     });
    }

    function Embedded(selector, groups)
    {
	var template_list   = ["resgroup-list"];
	var templates       = APT_OPTIONS.fetchTemplateList(template_list);
	listTemplate        = _.template(templates["resgroup-list"]);

	DoReservations(selector, groups)
    }

    /*
     * Load reservations from each am in the list and generate a table.
     */
    function DoReservations(selector, groups)
    {
	console.info("DoReservations", groups);

	if (!_.size(groups)) {
	    $('#nogroups').removeClass("hidden");
	    return;
	}
	var showportal = (window.ISADMIN && window.MAINSITE &&
			  !window.EMBEDDED_RESGROUPS ? true : false);

	// Generate the main template.
	var html = listTemplate({
	    "groups"       : groups,
	    "showcontrols" : false,
	    "showportal"   : showportal,
	    "showproject"  : true,
	    "showactivity" : true,
	    "showuser"     : true,
	    "showusing"    : true,
	    "showstatus"   : true,
	    "showselect"   : (window.EMBEDDED_RESGROUPS_SELECT ? true : false),
	    "isadmin"      : window.ISADMIN,
	});
	$(selector).html(html);

	// Format dates with moment before display.
	$(selector + ' .format-date').each(function() {
	    var date = $.trim($(this).html());
	    if (date != "") {
		$(this).html(moment(date).format("lll"));
	    }
	});
	// Show the proper status, for the group and for each reservation
	// in the group.
	_.each(groups, function(group, uuid) {
	    var groupid = selector + ' tr[data-uuid="' + uuid + '"] ';
	    var grow    = $(groupid);
	    var crow    = grow.next();

	    // Disable sorting if only one row.
	    if (_.size(group.clusters) == 1) {
		crow.find(".tablesorter.clusters-table thead th")
		    .addClass("sorter-false");
	    }
	    if (_.size(group.ranges) == 1) {
		crow.find(".tablesorter.ranges-table thead th")
		    .addClass("sorter-false");
	    }
	    if (_.size(group.routes) == 1) {
		crow.find(".tablesorter.routes-table thead th")
		    .addClass("sorter-false");
	    }
	    crow.find(".tablesorter").tablesorter({
		theme : 'bootstrap',
		widgets : [ "uitheme", "zebra"],
		headerTemplate : '{content} {icon}',
	    });

	    if (group.status == "approved") {
		$(groupid + " .group-status-column .status-approved")
		    .removeClass("hidden");
	    }
	    else if (group.status == "canceled") {
		$(groupid + " .group-status-column .status-canceled")
		    .removeClass("hidden");
	    }
	    else if (group.status == "pending") {
		$(groupid + " .group-status-column .status-pending")
		    .removeClass("hidden");
	    }
	    _.each(group.clusters, function(reservation, uuid) {
		var resid = 'tr[data-uuid="' + uuid + '"] ';
		var rrow  = crow.find(resid);

		if (reservation.deleted) {
		    rrow.find(".reservation-status-column .status-deleted")
			.removeClass("hidden");
		}
		else if (reservation.canceled) {
		    rrow.find(".reservation-status-column .status-canceled")
			.removeClass("hidden");
		}
		else if (reservation.approved) {
		    rrow.find(".reservation-status-column .status-approved")
			.removeClass("hidden");
		}
		else {
		    rrow.find(".reservation-status-column .status-pending")
			.removeClass("hidden");
		}
	    });
	    _.each(group.ranges, function(reservation, uuid) {
		var resid = 'tr[data-uuid="' + uuid + '"] ';
		var rrow  = crow.find(resid);

		if (reservation.canceled) {
		    rrow.find(".reservation-status-column .status-canceled")
			.removeClass("hidden");
		}
		else if (reservation.approved) {
		    rrow.find(".reservation-status-column .status-approved")
			.removeClass("hidden");
		}
		else {
		    rrow.find(".reservation-status-column .status-pending")
			.removeClass("hidden");
		}
	    });
	    _.each(group.routes, function(reservation, uuid) {
		var resid = 'tr[data-uuid="' + uuid + '"] ';
		var rrow  = crow.find(resid);

		if (reservation.canceled) {
		    rrow.find(".reservation-status-column .status-canceled")
			.removeClass("hidden");
		}
		else if (reservation.approved) {
		    rrow.find(".reservation-status-column .status-approved")
			.removeClass("hidden");
		}
		else {
		    rrow.find(".reservation-status-column .status-pending")
			.removeClass("hidden");
		}
	    });
	});
	$(selector + ' .tablesorter.resgroup-list')
	    .tablesorter({
		theme : 'bootstrap',
		widgets : [ "uitheme", "zebra"],
		headerTemplate : '{content} {icon}',

		textExtraction: {
		    '.status-extractor': function(node, table, cellIndex) {
			return $(node).find("> span:not(.hidden) .status-value").text();
		    },
		},
	    });
	$(selector + ' .tablesorter .tablesorter-childRow>td').hide();	
	$(selector + ' .tablesorter .show-childrow .expando')
	    .click(function (event) {
		event.preventDefault();
		// Determine current state for changing the chevron.
		var row = $(this).closest('tr')
		    .nextUntil('tr.tablesorter-hasChildRow').find('td')[0];
		var display = $(row).css("display");
		if (display == "none") {
		    $(this)
			.removeClass("glyphicon-chevron-right")
			.addClass("glyphicon-chevron-down");
		}
		else {
		    $(this)
			.removeClass("glyphicon-chevron-down")
			.addClass("glyphicon-chevron-right");
		}
		$(row).toggle();
	    });
	
	// This activates the tooltip subsystem.
	$(selector + ' [data-toggle="tooltip"]').tooltip({
	    delay: {"hide" : 250, "show" : 250},
	    placement: 'auto',
	});
	// This activates the popover subsystem.
	$(selector + ' [data-toggle="popover"]').popover({
	    placement: 'auto',
	    container: 'body',
	});

	if (window.ISADMIN && !window.EMBEDDED_RESGROUPS) {
	    DoAlternateTables(groups);
	}
    }

    function DoAlternateTables(groups)
    {
	var html = bytypeTemplate({
	    "groups"       : groups,
	    "showcontrols" : false,
	    "showproject"  : true,
	    "showactivity" : true,
	    "showuser"     : true,
	    "showusing"    : true,
	    "showstatus"   : true,
	    "isadmin"      : window.ISADMIN,
	});
	$("#groups-bytype").html(html);

	// Status column
	_.each(groups, function(group) {
	    _.each(group.clusters, function(reservation, uuid) {
		var resid = 'tr[data-uuid="' + uuid + '"] ';
		var rrow  = $('#groups-bytype ' + resid);

		if (reservation.canceled) {
		    rrow.find(".reservation-status-column .status-canceled")
			.removeClass("hidden");
		}
		else if (reservation.deleted) {
		    rrow.find(".reservation-status-column .status-deleted")
			.removeClass("hidden");
		}
		else if (reservation.approved) {
		    rrow.find(".reservation-status-column .status-approved")
			.removeClass("hidden");
		}
		else {
		    rrow.find(".reservation-status-column .status-pending")
			.removeClass("hidden");
		}
	    });
	});

	// See if we have any ranges.
	var ranges = 0;
	_.each(groups, function(group) {
	    //console.info(group, group.ranges);
	    if (_.size(group.ranges)) {
		ranges++;
	    }
	});
	if (ranges) {
	    html = byrangeTemplate({
		"groups"       : groups,
		"showcontrols" : false,
		"showproject"  : true,
		"showactivity" : true,
		"showuser"     : true,
		"showusing"    : true,
		"showstatus"   : true,
		"isadmin"      : window.ISADMIN,
	    });
	    $("#groups-byrange").html(html);
	    
	    // Status column
	    _.each(groups, function(group) {
		_.each(group.ranges, function(reservation, uuid) {
		    var resid = 'tr[data-uuid="' + uuid + '"] ';
		    var rrow  = $('#groups-byrange ' + resid);

		    if (reservation.canceled) {
			rrow.find(".reservation-status-column " +
				  ".status-canceled")
			    .removeClass("hidden");
		    }
		    else if (reservation.approved) {
			rrow.find(".reservation-status-column " +
				  ".status-approved")
			    .removeClass("hidden");
		    }
		    else {
			rrow.find(".reservation-status-column " +
				  ".status-pending")
			    .removeClass("hidden");
		    }
		});
	    });
	}
	// See if we have any routes
	var routes = 0;
	_.each(groups, function(group) {
	    //console.info(group, group.routes);
	    if (_.size(group.routes)) {
		routes++;
	    }
	});
	if (routes) {
	    html = byrouteTemplate({
		"groups"       : groups,
		"showcontrols" : false,
		"showproject"  : true,
		"showactivity" : true,
		"showuser"     : true,
		"showusing"    : true,
		"showstatus"   : true,
		"isadmin"      : window.ISADMIN,
	    });
	    $("#groups-byroute").html(html);
	    
	    // Status column
	    _.each(groups, function(group) {
		_.each(group.routes, function(reservation, uuid) {
		    var resid = 'tr[data-uuid="' + uuid + '"] ';
		    var rrow  = $('#groups-byroute ' + resid);

		    if (reservation.canceled) {
			rrow.find(".reservation-status-column " +
				  ".status-canceled")
			    .removeClass("hidden");
		    }
		    else if (reservation.approved) {
			rrow.find(".reservation-status-column " +
				  ".status-approved")
			    .removeClass("hidden");
		    }
		    else {
			rrow.find(".reservation-status-column " +
				  ".status-pending")
			    .removeClass("hidden");
		    }
		});
	    });
	}

	// Format dates with moment before display.
	$('#groups-bytype .format-date, #groups-byrange .format-date, ' +
	  '#groups-byroute .format-date')
	    .each(function() {
		var date = $.trim($(this).html());
		if (date != "") {
		    $(this).html(moment(date).format("lll"));
		}
	    });
	$("#groups-bytype-div").removeClass("hidden");	    
	if (ranges) {
	    $("#groups-byrange-div").removeClass("hidden");
	}
	if (routes) {
	    $("#groups-byroute-div").removeClass("hidden");
	}
	$('#groups-bytype .tablesorter, #groups-byrange .tablesorter,' +
	  '#groups-byroute .tablesorter')
	    .tablesorter({
		theme : 'bootstrap',
		widgets : [ "uitheme", "zebra"],
		headerTemplate : '{content} {icon}',

		textExtraction: {
		    '.status-extractor': function(node, table, cellIndex) {
			return $(node).find("> span:not(.hidden) .status-value").text();
		    },
		},
	    });

	// This activates the tooltip subsystem.
	$('#groups-bytype  [data-toggle="tooltip"], ' +
	  '#groups-byrange [data-toggle="tooltip"], ' +
	  '#groups-byroute [data-toggle="tooltip"]').tooltip({
	      delay: {"hide" : 250, "show" : 250},
	      placement: 'auto',
	  });
	// This activates the popover subsystem.
	$('#groups-bytype  [data-toggle="popover"], ' +
	  '#groups-byrange [data-toggle="popover"], ' +
	  '#groups-byroute [data-toggle="popover"]').popover({
	      placement: 'auto',
	      container: 'body',
	  });
    }

    // Helper.
    function decodejson(id) {
	return JSON.parse(_.unescape($(id)[0].textContent));
    }
    if (window.EMBEDDED_RESGROUPS) {
	window.DrawResGroupList = function (selector, groups) {
	    Embedded(selector, groups);
	};
    }
    else {
	$(document).ready(initialize);
    }
});


