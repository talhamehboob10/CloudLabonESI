$(function ()
{
    'use strict';

    var template_list   = ["list-reservations", "reservation-list",
			   "prereservation-list",
			   "confirm-modal", "resusage-list", "resusage-graph",
			   "oops-modal", "waitwait-modal"];
    var templates       = APT_OPTIONS.fetchTemplateList(template_list);    
    var mainTemplate    = _.template(templates["list-reservations"]);
    var listTemplate    = _.template(templates["reservation-list"]);
    var prelistTemplate = _.template(templates["prereservation-list"]);
    var usageTemplate   = _.template(templates["resusage-list"]);
    var graphTemplate   = _.template(templates["resusage-graph"]);
    var confirmString   = templates["confirm-modal"];
    var oopsString      = templates["oops-modal"];
    var waitwaitString  = templates["waitwait-modal"];
    var amlist = null;
    
    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);
	amlist  = decodejson('#amlist-json');

	$('#main-body').html(mainTemplate({"amlist" : amlist}));
	$('#oops_div').html(oopsString);	
	$('#waitwait_div').html(waitwaitString);
	$('#confirm_div').html(confirmString);
	
	LoadData();
    }

    /*
     * Load reservations from each am in the list and generate a table.
     */
    function LoadData()
    {
	var amcount  = Object.keys(amlist).length;
	var rescount = 0;	
	
	_.each(amlist, function(urn, name) {
	    var callback = function(json) {
		console.log("LoadData", name, json);
		
		// Kill the spinner.
		amcount--;
		if (amcount <= 0) {
		    $('#spinner').addClass("hidden");
		}
		if (json.code) {
		    console.log("Could not get reservation data for " +
				name + ": " + json.value);
		    $('#' + name + " .res-error").html(json.value);
		    $('#' + name + " .res-error").removeClass("hidden");
		    $('#' + name).removeClass("hidden");
		    return;
		}
		var prereservations = json.value.prereservations;
		var reservations = json.value.reservations;
		rescount += _.size(reservations) + _.size(prereservations);

		if (_.size(reservations) == 0 && _.size(prereservations) == 0) {
		    if (amcount == 0 && rescount == 0) {
			// No reservations at all, show the message.
			$('#noreservations').removeClass("hidden");
		    }
		    return;
		}
		if (_.size(reservations)) {
		    DoReservations(name, urn, json);
		    $('#' + name + ' .reservation-panel')
			.removeClass("hidden");
		}
		if (_.size(prereservations)) {
		    DoPreReservations(name, urn, json);
		    $('#' + name + ' .prereservation-panel')
			.removeClass("hidden");
		}
		$('#' + name).removeClass("hidden");
	    }
	    var xmlthing = sup.CallServerMethod(null, "reserve",
						"ListReservations",
						{"cluster" : name});
	    xmlthing.done(callback);
	});
    }

    /*
     * Build the reservation table.
     */
    function DoReservations(name, urn, json)
    {
	var reservations = json.value.reservations;
	var panelid      = "#" + name + " .reservation-panel";

	// Generate the main template.
	var html = listTemplate({
	    "reservations" : reservations,
	    "showcontrols" : true,
	    "showproject"  : true,
	    "showactivity" : true,
	    "showuser"     : true,
	    "showusing"    : true,
	    "showstatus"   : true,
	    "name"         : name,
	    "isadmin"      : window.ISADMIN,
	});
	$(panelid + " .panel-body").html(html);

	// Show the proper status now, we might change it later.
	_.each(reservations, function(value, uuid) {
	    var id = panelid + ' tr[data-uuid="' + uuid + '"] ';

	    if (value.cancel) {
		$(id + " .status-column .status-canceled")
		    .removeClass("hidden");
	    }
	    else if (value.approved) {
		$(id + " .status-column .status-approved")
		    .removeClass("hidden");
	    }
	    else {
		$(id + " .status-column .status-pending")
		    .removeClass("hidden");

		if (window.ISADMIN) {
		    // Bind a deny handler,
		    $(id + ' .deny-button').click(function() {
			DenyReservation($(this).closest('tr'));
			return false;
		    });
		    $(id + ' .deny-button').removeClass("invisible");
		    // Bind an approve handler
		    $(id + ' .approve-button').click(function() {
			ApproveReservation($(this).closest('tr'));
			return false;
		    });
		    $(id + ' .approve-button').removeClass("invisible");
		}
	    }
	    if (value.approved &&
		_.has(value, 'history') && value.history.length) {
		$(id + " .resgraph-button").removeClass("invisible");

		// Bind usage history graph.
		$(id + ' .resgraph-button').click(function() {
		    DrawHistoryGraph(value);
		    return false;
		});
	    }
	});

	// Format dates with moment before display.
	$(panelid + ' .format-date').each(function() {
	    var date = $.trim($(this).html());
	    if (date != "") {
		$(this).html(moment(date).format("lll"));
	    }
	});
	$(panelid + ' .tablesorter')
	    .tablesorter({
		theme : 'bootstrap',
		widgets: ["uitheme", "zebra"],
		headerTemplate : '{content} {icon}',
	    });
	// Bind a delete handler.
	$(panelid + ' .delete-button').click(function() {
	    DeleteReservation($(this).closest('tr'));
	    return false;
	});
	if (window.ISADMIN) {
	    // Bind info and warning handler.
	    $(panelid + ' .info-button').click(function() {
		ReservationInfoOrWarning("info", $(this).closest('tr'));
		return false;
	    });
	    $(panelid + ' .warn-button').click(function() {
		ReservationInfoOrWarning("warn", $(this).closest('tr'));
		return false;
	    });
	    // Bind a cancel cancellation handler.
	    $(panelid + ' .cancel-cancel-button').click(function() {
		CancelCancellation($(this).closest('tr'));
		return false;
	    });
	}
	if (_.has(json.value, "history")) {
	    var history = json.value.history;
	    console.info("history", name, history);

	    $(panelid + " table tbody tr").each(function () {
		// Grab the uuid, it is the key into the reservation list.
		var uuid = $(this).attr('data-uuid');
		var details = reservations[uuid];
		var type    = details.type;
		var urn     = details.project;
		var pid     = details.pid;

		//console.info("uuid", uuid, details);

		// No history for the project.
		if (!_.has(history, urn))
		    return;

		//console.info("history", urn, history[urn]);
		/*
		 * Search history entries and prune to only
		 * those using the type reserved. Might not be
		 * any experiments using this type.
		 */
		var entries = [];

		for (var i = 0; i < history[urn].length; i++) {
		    var entry = history[urn][i];

		    if (_.has(entry.types, type)) {
			entries.push(entry);
		    }
		}
		if (entries.length == 0)
		    return;

		// Contents of the new modal.
		var html = usageTemplate({"uuid"    : uuid,
					  "type"    : type,
					  "project" : pid,
					  "history" : entries});
		// And add to all the new modals.
		$('#resusage-modals').append(html);

		// Show/Activate the button in the list that shows modal.
		$(this).find(".resusage-button").click(function (event) {
		    event.preventDefault();
		    sup.ShowModal('#' + "resusage-modal-" + uuid);
		});
		$(this).find(".resusage-button")
		    .removeClass("invisible");

		// Format dates in the modal with moment before display.
		$('#resusage-modal-' + uuid + ' .format-date').each(function() {
		    var date = $.trim($(this).html());
		    if (date != "") {
			$(this).html(moment(date * 1000).format("lll"));
		    }
		});
	    });
	}
	// This activates the tooltip subsystem.
	$(panelid + ' [data-toggle="tooltip"]').tooltip({
	    delay: {"hide" : 250, "show" : 250},
	    placement: 'auto',
	});
	// This activates the popover subsystem.
	$(panelid + ' [data-toggle="popover"]').popover({
	    placement: 'auto',
	    container: 'body',
	});
    }
    /*
     * Build the prereservation table.
     */
    function DoPreReservations(name, urn, json)
    {
	var prereservations = json.value.prereservations;
	var panelid      = "#" + name + " .prereservation-panel";

	// Generate the main template.
	var html = prelistTemplate({
	    "prereservations" : prereservations,
	    "showcontrols"    : true,
	    "showproject"     : true,
	    "showactivity"    : true,
	    "showuser"        : true,
	    "showusing"       : true,
	    "showstatus"      : true,
	    "name"            : name,
	    "isadmin"         : window.ISADMIN,
	});
	$(panelid + " .panel-body").html(html);

	// Format dates with moment before display.
	$(panelid + ' .format-date').each(function() {
	    var date = $.trim($(this).html());
	    if (date != "") {
		$(this).html(moment(date).format("lll"));
	    }
	});

	// Show the proper status now, we might change it later.
	_.each(prereservations, function(value, uuid) {
	    var id = panelid + ' tr[data-uuid="' + uuid + '"] ';

	    if (value.approved) {
		$(id + " .status-column .status-approved")
		    .removeClass("hidden");
	    }
	    else {
		$(id + " .status-column .status-pending")
		    .removeClass("hidden");

		if (window.ISADMIN) {
		    // Bind a deny handler,
		    $(id + ' .deny-button').click(function() {
			DenyReservation($(this).closest('tr'));
			return false;
		    });
		    $(id + ' .deny-button').removeClass("invisible");
		    // Bind an approve handler
		    $(id + ' .approve-button').click(function() {
			ApproveReservation($(this).closest('tr'));
			return false;
		    });
		    $(id + ' .approve-button').removeClass("invisible");
		}
	    }
	});
	$(panelid + ' .tablesorter')
	    .tablesorter({
		theme : 'bootstrap',
		widgets: ["uitheme", "zebra"],
		headerTemplate : '{content} {icon}',
	    });
	$(panelid + ' .tablesorter .tablesorter-childRow>td').hide();	
	$(panelid + ' .tablesorter .show-childrow').click(function (event) {
	    // Determine current state for changing the chevron.
	    var row = $(this).closest('tr')
		.nextUntil('tr.tablesorter-hasChildRow').find('td')[0];
	    var display = $(row).css("display");
	    if (display == "none") {
		$(this).find("span")
		    .removeClass("glyphicon-chevron-right")
		    .addClass("glyphicon-chevron-down");
	    }
	    else {
		$(this).find("span")
		    .removeClass("glyphicon-chevron-down")
		    .addClass("glyphicon-chevron-right");
	    }
	    $(row).toggle();
	});

	// Bind a delete handler.
	$(panelid + ' .delete-button').click(function() {
	    DeleteReservation($(this).closest('tr'));
	    return false;
	});
	if (window.ISADMIN) {
	    // Bind info and warning handler.
	    $(panelid + ' .info-button').click(function() {
		ReservationInfoOrWarning("info", $(this).closest('tr'));
		return false;
	    });
	    $(panelid + ' .warn-button').click(function() {
		ReservationInfoOrWarning("warn", $(this).closest('tr'));
		return false;
	    });
	    // Bind a cancel cancellation handler.
	    $(panelid + ' .cancel-cancel-button').click(function() {
		CancelCancellation($(this).closest('tr'));
		return false;
	    });
	}

	// This activates the tooltip subsystem.
	$(panelid + ' [data-toggle="tooltip"]').tooltip({
	    delay: {"hide" : 250, "show" : 250},
	    placement: 'auto',
	});
	// This activates the popover subsystem.
	$(panelid + ' [data-toggle="popover"]').popover({
	    placement: 'auto',
	    container: 'body',
	});
    }

    /*
     * Delete a reservation. When complete, delete the table row.
     */
    function DeleteReservation(row) {
	// This is what we are deleting.
	var uuid = $(row).attr('data-uuid');
	var pid  = $(row).attr('data-pid');
	var type = $(row).attr('data-type');
	var cluster = $(row).attr('data-cluster');
	var table   = $(row).closest("table");

	// Callback for the delete request.
	var callback = function (json) {
	    sup.HideModal('#waitwait-modal');
	    console.log("delete", json);
	    if (json.code) {
		sup.SpitOops("oops", json.value);
		return;
	    }
	    $(row).remove();
	    table.trigger('update');
	};
	// Bind the confirm button in the modal. Do the deletion.
	$('#confirm_modal #confirm_delete').click(function () {
	    sup.HideModal('#confirm_modal');
	    sup.ShowModal('#waitwait-modal');
	    var xmlthing = sup.CallServerMethod(null, "reserve",
						"Delete",
						{"uuid"    : uuid,
						 "pid"     : pid,
						 "type"    : type,
						 "cluster" : cluster});
	    xmlthing.done(callback);
	});
	// Handler so we know the user closed the modal. We need to
	// clear the confirm button handler.
	$('#confirm_modal').on('hidden.bs.modal', function (e) {
	    $('#confirm_modal #confirm_delete').unbind("click");
	    $('#confirm_modal').off('hidden.bs.modal');
	})
	sup.ShowModal("#confirm_modal");
    }
    
    /*
     * Deny a reservation with cause. When complete, delete the table row.
     */
    function DenyReservation(row) {
	// This is what we are deleting.
	var uuid = $(row).attr('data-uuid');
	var pid  = $(row).attr('data-pid');
	var type    = $(row).attr('data-type');
	var cluster = $(row).attr('data-cluster');
	var table   = $(row).closest("table");
	
	// Callback for the delete request.
	var callback = function (json) {
	    sup.HideModal('#waitwait-modal');
	    console.log("deny", json);
	    if (json.code) {
		sup.SpitOops("oops", json.value);
		return;
	    }
	    $(row).remove();
	    table.trigger('update');
	};
	// Bind the confirm button in the modal. Do the deletion.
	$('#deny-modal #confirm-deny').click(function () {
	    sup.HideModal('#deny-modal', function () {
		var reason  = $('#deny-reason').val();
		sup.ShowModal('#waitwait-modal');
		var xmlthing = sup.CallServerMethod(null, "reserve",
						    "Delete",
						    {"uuid"    : uuid,
						     "pid"     : pid,
						     "type"    : type,
						     "cluster" : cluster,
						     "reason"  : reason});
		xmlthing.done(callback);
	    });
	});
	// Handler so we know the user closed the modal. We need to
	// clear the confirm button handler.
	$('#deny-modal').on('hidden.bs.modal', function (e) {
	    $('#deny-modal #confirm-deny').unbind("click");
	    $('#deny-modal').off('hidden.bs.modal');
	})
	sup.ShowModal("#deny-modal");
    }
    
    /*
     * Approve a reservation.
     */
    function ApproveReservation(row) {
	// This is what we are deleting.
	var uuid = $(row).attr('data-uuid');
	var cluster = $(row).attr('data-cluster');
	var type    = $(row).attr('data-type');
	
	var callback = function (json) {
	    sup.HideModal('#waitwait-modal');
	    console.log("approve", json);
	    if (json.code) {
		sup.SpitOops("oops", json.value);
		return;
	    }
	    $(row).find(".status-column .status-pending")
		.addClass("hidden");
	    $(row).find(".status-column .status-approved")
		.removeClass("hidden");
	    $(row).find('.approve-button').addClass("invisible");
	    $(row).find('.deny-button').addClass("invisible");
	};
	// Bind the confirm button in the modal. Do the approval.
	$('#approve-modal #confirm-approve').click(function () {
	    sup.HideModal('#approve-modal', function () {
		var message = $('#approve-modal .user-message').val().trim();
		sup.ShowModal('#waitwait-modal');
		var xmlthing = sup.CallServerMethod(null, "reserve",
						    "Approve",
						    {"uuid"    : uuid,
						     "type"    : type,
						     "message" : message,
						     "cluster" : cluster});
		xmlthing.done(callback);
	    });
	});
	// Handler so we know the user closed the modal. We need to
	// clear the confirm button handler.
	$('#approve-modal').on('hidden.bs.modal', function (e) {
	    $('#approve-modal #confirm-approve').unbind("click");
	    $('#approve-modal').off('hidden.bs.modal');
	})
	sup.ShowModal("#approve-modal");
    }
    
    /*
     * Ask for info about reservation (usage, lack of usage, etc).
     */
    function ReservationInfoOrWarning(which, row) {
	// This is what we are deleting.
	var uuid    = $(row).attr('data-uuid');
	var pid     = $(row).attr('data-pid');
	var uid_idx = $(row).attr('data-uid_idx');
	var cluster = $(row).attr('data-cluster');
	var type    = $(row).attr('data-type');
	var table   = $(row).closest("table");
	var warning = (which == "warn" ? 1 : 0);
	var modal   = (warning ? "#warn-modal" : "#info-modal");
	var method  = (warning ? "WarnUser" : "RequestInfo");
	var cancel  = 0;

	var callback = function (json) {
	    sup.HideModal('#waitwait-modal');
	    console.log(method, json);
	    if (json.code) {
		sup.SpitOops("oops", json.value);
		return;
	    }
	    // Reset the status column.
	    if (cancel) {
		$(row).find(".status-column .status-approved")
		    .addClass("hidden");
		$(row).find(".status-column .status-canceled")
		    .removeClass("hidden");
	    }
	};
	// Bind the confirm button in the modal. 
	$(modal + ' .confirm-button').click(function () {
	    var message = $(modal + ' .user-message').val();
	    if (!warning && message.trim().length == 0) {
		$(modal + ' .nomessage-error').removeClass("hidden");
		return;
	    }
	    if (warning && $('#schedule-cancellation').is(":checked")) {
		cancel = 1;
	    }
	    var args = {"uuid"    : uuid,
			"pid"     : pid,
			"uid_idx" : uid_idx,
			"cluster" : cluster,
			"type"    : type,
			"cancel"  : cancel,
			"message" : message};
	    console.info("warninfo", args);
	    
	    sup.HideModal(modal, function () {
		sup.ShowModal('#waitwait-modal');
		var xmlthing = sup.CallServerMethod(null, "reserve",
						    method, args);
		xmlthing.done(callback);
	    });
	});
	// Handler so we know the user closed the modal. We need to
	// clear the confirm button handler.
	$(modal).on('hidden.bs.modal', function (e) {
	    $(modal + ' .confirm-button').unbind("click");
	    $(modal).off('hidden.bs.modal');
	})
	// Hide error
	if (!warning) {
	    $(modal + ' .nomessage-error').addClass("hidden");
	}
	sup.ShowModal(modal);
    }

    function CancelCancellation(row) {
	// This is what we are working on.
	var uuid    = $(row).attr('data-uuid');
	var pid     = $(row).attr('data-pid');
	var cluster = $(row).attr('data-cluster');
	var type    = $(row).attr('data-type');
	var table   = $(row).closest("table");
	
	// Callback for the request.
	var callback = function (json) {
	    sup.HideModal('#waitwait-modal');
	    if (json.code) {
		console.log("cancel cancel", json);
		sup.SpitOops("oops", json.value);
		return;
	    }
	    // Reset the status column.
	    $(row).find(".status-column .status-canceled")
		.addClass("hidden");
	    $(row).find(".status-column .status-approved")
		.removeClass("hidden");
	};
	// Bind the confirm button in the modal. 
	$('#confirm-cancel-cancel-button').click(function () {
	    sup.HideModal('#cancel-cancel-modal', function () {
		sup.ShowModal('#waitwait-modal');
		var xmlthing = sup.CallServerMethod(null, "reserve",
						    "Cancel",
						    {"uuid"    : uuid,
						     "clear"   : 1,
						     "pid"     : pid,
						     "type"    : type,
						     "cluster" : cluster});
		xmlthing.done(callback);
	    });
	});
	// Handler so we know the user closed the modal. We need to
	// clear the confirm button handler.
	$('#cancel-cancel-modal').on('hidden.bs.modal', function (e) {
	    $('#confirm-cancel-cancel-button').unbind("click");
	    $('#cancel-cancel-modal').off('hidden.bs.modal');
	})
	sup.ShowModal("#cancel-cancel-modal");
    }

    // Draw the history bar graph.
    function DrawHistoryGraph(details)
    {
	// Setup a handler to draw the large version graph in the modal.
	$('#resusage-graph-modal').on('shown.bs.modal', function() {
	    window.DrawResHistoryGraph({"details"    : details,
					"graphid"    : '#resusage-graph-modal',
					"xaxislabel" : true});
	});
	
	// Make sure nothing left behind before we show it.
	$('#resusage-graph-modal svg').html("");
	// Gack, this stuff gets left behind.
	d3.selectAll('.nvtooltip').remove();

	$('#resusage-graph-modal .resusage-graph-details')
	    .html("(" + details.nodes + " " + details.type + " nodes)");
	
	sup.ShowModal('#resusage-graph-modal', function () {
	    // Need to unbind the hook above.
	    $('#resusage-graph-modal').off('shown.bs.modal');
	});

    }
    // Helper.
    function decodejson(id) {
	return JSON.parse(_.unescape($(id)[0].textContent));
    }
    $(document).ready(initialize);
});


