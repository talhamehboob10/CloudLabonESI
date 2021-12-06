$(function ()
{
    'use strict';

    var template_list   = ["reserve-request", "reserve-faq",
			   "reservation-graph", "oops-modal", "waitwait-modal",
			   "resusage-graph"];
    var templates       = APT_OPTIONS.fetchTemplateList(template_list);    
    var oopsString      = templates["oops-modal"];
    var waitwaitString  = templates["waitwait-modal"];
    var mainTemplate    = _.template(templates["reserve-request"]);
    var graphTemplate   = _.template(templates["reservation-graph"]);
    var usageTemplate   = _.template(templates["resusage-graph"]);
    var fields       = null;
    var projlist     = null;
    var amlist       = null;
    var isadmin      = false;
    var editing      = false;
    var buttonstate  = "check";
    var forecasts    = {};
    var IDEAL_STARTHOUR = 7;	// 7am start time preferred. 
    
    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);

	isadmin  = window.ISADMIN;
	editing  = window.EDITING; 
	fields   = JSON.parse(_.unescape($('#form-json')[0].textContent));
	projlist = JSON.parse(_.unescape($('#projects-json')[0].textContent));
	amlist   = JSON.parse(_.unescape($('#amlist-json')[0].textContent));

	GeneratePageBody(fields);

	// Now we can do this. 
	$('#oops_div').html(oopsString);	
	$('#waitwait_div').html(waitwaitString);

	/*
	 * In edit mode, we ask for the reservation details from the
	 * backend cluster and then update the form.
	 */
	if (editing) {
	    PopulateReservation();
	    $('#reserve-delete-button').click(function (e) {
		e.preventDefault();
		Delete();
	    });
	}
	else {
	    // Give this a slight delay so that the spinners appear.
	    // Not really sure why they do not.
	    setTimeout(function () {
		LoadReservations();
	    }, 100);
	}

	if (1) {
	    $('#reserve-request-form .findfit-button')
		.click(function (event) {
		    event.preventDefault();
		    FindFit();
		});
	}
    }

    //
    // Moved into a separate function since we want to regen the form
    // after each submit, which happens via ajax on this page. 
    //
    function GeneratePageBody(formfields)
    {
	// Generate the template.
	var html = mainTemplate({
	    formfields:		formfields,
	    projects:           projlist,
	    amlist:		amlist,
	    isadmin:		isadmin,
	    editing:		editing,
	});
	html = aptforms.FormatFormFieldsHorizontal(html);
	$('#main-body').html(html);
	$('.faq-contents').html(templates["reserve-faq"]);
	// Graph list(s).
	html = "";
	_.each(amlist, function(details, urn) {
	    var graphid = 'resgraph-' + details.nickname;

	    html += graphTemplate({"details"        : details,
				   "graphid"        : graphid,
				   "title"          : details.nickname,
				   "urn"            : urn,
				   "showhelp"       : true,
				   "showfullscreen" : true});
	});
	$('#reservation-lists').html(html);

	// Handler for the Help button
	$('#reservation-help-button').click(function (event) {
	    event.preventDefault();
	    sup.ShowModal('#reservation-help-modal');
	});
	
	// Handler for the FAQ link.
	$('#reservation-faq-button').click(function (event) {
	    event.preventDefault();
	    sup.HideModal('#reservation-help-modal',
			  function () {
			      sup.ShowModal('#reservation-faq-modal');
			  });
	});
	// Set the manual link since the FAQ is not a template.
	$('#reservation-manual').attr("href", window.MANUAL);

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
	
	// Handler for cluster change to show the type list.
	$('#reserve-request-form #cluster').change(function (event) {
	    $("#reserve-request-form #cluster option:selected").
		each(function() {
		    HandleClusterChange($(this).val());
		    return;
		});
	});
	// Handler for hardware type selector,
	$('#reserve-request-form #type').change(function (event) {
	    HandleTypeChange();
	});
	// Handle submit button.
	$('#reserve-submit-button').click(function (event) {
	    event.preventDefault();
	    if (buttonstate == "check") {
		CheckForm();
	    }
	    else {
		Reserve();
	    }
	});
	// Handle modal submit button.
	$('#confirm-reservation #commit-reservation').click(function (event) {
	    if (buttonstate == "submit") {
		Reserve();
	    }
	});

	// Insert datepickers after html inserted.
	$("#reserve-request-form #start_day").datepicker({
	    minDate: 0,		/* earliest date is today */
	    showButtonPanel: true,
	    onSelect: function (dateString, dateobject) {
		DateChange("#start_day");
		modified_callback();
	    }
	});
	$("#reserve-request-form #end_day").datepicker({
	    minDate: 0,		/* earliest date is today */
	    showButtonPanel: true,
	    onSelect: function (dateString, dateobject) {
		DateChange("#end_day");
		modified_callback();
	    }
	});
	/*
	 * Callback when something changes so that we can toggle the
	 * button from Submit to Check.
	 */
	var modified_callback = function () {
	    ToggleSubmit(true, "check");
	};
	aptforms.EnableUnsavedWarning('#reserve-request-form',
				      modified_callback);

    }
    
    /*
     * When the date selected is today, need to disable the hours
     * before the current hour. Also set the initial hour to a
     * reasonable hour, like 7am since that is a good start work time
     * for most people. Basically, try to avoid unused reservations
     * between midnight and 7am, unless people specifically want that
     * time.
     */
    function DateChange(which)
    {
	var date = $("#reserve-request-form " + which).datepicker("getDate");
	var now = new Date();
	var selecter;

	if (which == "#start_day") {
	    selecter = "#reserve-request-form #start_hour";
	}
	else {
	    selecter = "#reserve-request-form #end_hour";
	}
	// Remember if the user already set the hour.
	var hourset =
	    ($(selecter + " option:selected").val() == "" ? false : true);
	
	if (moment(date).isSame(Date.now(), "day")) {
	    for (var i = 0; i <= now.getHours(); i++) {

		/*
		 * Before we disable the option, see if it is selected.
		 * If so, we want make the user re-select the hour.
		 */
		if ($(selecter + " option:selected").val() == i) {
		    $(selecter).val("");
		}
		$(selecter + " option[value='" + i + "']")
		    .attr("disabled", "disabled");
	    }
	}
	else {
	    for (var i = 0; i <= now.getHours(); i++) {
		$(selecter + " option[value='" + i + "']")
		    .removeAttr("disabled");
	    }
	}
	/*
	 * Ok, init the hour if not set.
	 */
	if (!hourset) {
	    $(selecter + ' option[value=' + IDEAL_STARTHOUR + ']')
		.prop('selected', 'selected');
	}
    }

    //
    // Check form validity. This does not check whether the reservation
    // is valid.
    //
    function CheckForm()
    {
	var start = null;
	var end   = null;
	
	var checkonly_callback = function(json) {
	    if (json.code) {
		if (json.code != 2) {
		    sup.SpitOops("oops", json.value);		    
		}
		return;
	    }
	    // Set the number of days, so that user can then search if
	    // the start/end selected do not work.
	    var hours = end.diff(start, "hours");
	    var days  = hours / 24;
	    $('#reserve-request-form [name=days]')
		.val(days.toFixed(1));
	    
	    // Now check the actual reservation validity.
	    ValidateReservation();
	}
	/*
	 * Before we submit, set the start/end fields to UTC time.
	 */
	var start_day  = $('#reserve-request-form [name=start_day]').val();
	var start_hour = $('#reserve-request-form [name=start_hour]').val();
	if (start_day && !start_hour) {
	    aptforms.GenerateFormErrors('#reserve-request-form',
					{"start" : "Missing hour"});
	    return;
	}
	else if (!start_day && start_hour) {
	    aptforms.GenerateFormErrors('#reserve-request-form',
					{"start" : "Missing day"});
	    return;
	}
	else if (start_day && start_hour) {
	    start = moment(start_day, "MM/DD/YYYY");
	    start.hour(start_hour);
	    $('#reserve-request-form [name=start]').val(start.format());
	}
	var end_day  = $('#reserve-request-form [name=end_day]').val();
	var end_hour = $('#reserve-request-form [name=end_hour]').val();
	if (end_day && !end_hour) {
	    aptforms.GenerateFormErrors('#reserve-request-form',
					{"end" : "Missing hour"});
	    return;
	}
	else if (!end_day && end_hour) {
	    aptforms.GenerateFormErrors('#reserve-request-form',
					{"end" : "Missing day"});
	    return;
	}
	else if (end_day && end_hour) {
	    end = moment(end_day, "MM/DD/YYYY");
	    end.hour(end_hour);
	    $('#reserve-request-form [name=end]').val(end.format());
	}
	aptforms.CheckForm('#reserve-request-form', "reserve",
			   "Validate", checkonly_callback);
    }

    

    // Call back from the graphs to change the dates on a blank form
    function GraphClick(when, type)
    {
	//console.info("graphclick", when, type);
	// Bump to next hour. Will be confusing at midnight.
	when.setHours(when.getHours() + 1);

	if (! editing) {
	    $("#reserve-request-form #start_day").datepicker("setDate", when);
	    $("#reserve-request-form [name=start_hour]").val(when.getHours());
	    if (type !== undefined) {
		if ($('#reserve-request-form ' +
		      '[name=type] option:selected').val() != type) {
		    $('#reserve-request-form ' +
		      '[name=type] option:selected').removeAttr('selected');
		    $('#reserve-request-form [name=type] ' + 
		      'option[value="' + type + '"]')
			.prop("selected", "selected");
		}
	    }
	    $('#reserve-request-form [name=count]').focus();
	    aptforms.MarkFormUnsaved();
	}
    }
    // Set the cluster after clicking on a graph.
    function SetCluster(nickname, urn)
    {
	//console.info("SetCluster", nickname);
	var id = "resgraph-" + nickname;
	
	if ($('#reservation-lists :first-child').attr("id") != id) {
	    $('#' + id).fadeOut("fast", function () {
		if ($(window).scrollTop()) {
		    $('html, body').animate({scrollTop: '0px'},
					    500, "swing",
					    function () {
						$('#reservation-lists')
						    .prepend($('#' + id));
						$('#' + id)
						    .fadeIn("fast");
					    });
		}
		else {
		    $('#reservation-lists').prepend($('#' + id));
		    $('#' + id).fadeIn("fast");
		}
	    });
	}
	if ($('#reserve-request-form ' +
	      '[name=cluster] option:selected').val() != urn) {
	    $('#reserve-request-form ' +
	      '[name=cluster] option:selected').removeAttr('selected');
	    $('#reserve-request-form ' +
	      '[name=cluster] option[value="' + urn + '"]')
		.prop("selected", "selected");
	    HandleClusterChange(urn);
	    aptforms.MarkFormUnsaved();
	}
    }

    /*
     * Load anonymized reservations from each am in the list and
     * generate tables.
     */
    function LoadReservations(project)
    {
	_.each(amlist, function(details, urn) {
 	    var callback = function(json) {
		console.log("LoadReservations", json);
		var id = "resgraph-" + details.nickname;
		
		// Kill the spinner.
		$('#' + id + ' .resgraph-spinner').addClass("hidden");

		if (json.code) {
		    console.log("Could not get reservation data for " +
				details.name + ": " + json.value);
		    
		    $('#' + id + ' .resgraph-error').html(json.value);
		    $('#' + id + ' .resgraph-error').removeClass("hidden");
		    return;
		}
		ProcessForecast(urn, json.value.forecast);

		ShowResGraph({"forecast"  : json.value.forecast,
			      "selector"  : id,
			      "skiptypes"      : json.value.prunelist,
			      "click_callback" : function(when, type) {
				  if (!editing) {
				      SetCluster(details.nickname, urn);
				  }
				  GraphClick(when, type);
			      }});

		$('#' + id + ' .resgraph-fullscreen')
		    .click(function (event) {
			event.preventDefault();
			// Panel title in the modal.
			$('#resgraph-modal .cluster-name')
			    .html(details.nickname);
			// Clear the existing graph first.
			$('#resgraph-modal svg').html("");
			// Modal needs to show before we can draw the graph.
			$('#resgraph-modal').on('shown.bs.modal', function() {
			    ShowResGraph({"forecast"  : json.value.forecast,
					  "selector"  : "resgraph-modal",
					  "skiptypes"      : skiptypes,
					  "click_callback" : GraphClick});
			});
			sup.ShowModal('#resgraph-modal', function () {
			    $('#resgraph-modal').off('shown.bs.modal');
			});
		    });
 	    }
	    var args = {"cluster" : details.nickname};
	    if (project !== undefined) {
		args["project"] = project;
	    }
	    var xmlthing = sup.CallServerMethod(null, "reserve",
						"ReservationInfo", args);
	    xmlthing.done(callback);
	});
    }

    //
    // Process the forecast so we use it for reservation fitting.
    //
    function ProcessForecast(cluster, forecast)
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
	//console.info("forecast", cluster, forecast);
	forecasts[cluster] = forecast;
    }
    /*
     * Try to find the first fit.
     */
    function FindFit()
    {
	var days     = $('#reserve-request-form [name=days]').val();
	var count    = $('#reserve-request-form [name=count]').val();
	var type;
	var cluster;

	if (editing) {
	    type     = $('#reserve-request-form [name=type]').val();
	    cluster  = $('#reserve-request-form [name=cluster]').val();
	}
	else {
	    type     = $('#reserve-request-form ' +
			 '[name=type] option:selected').val();
	    cluster  = $('#reserve-request-form ' +
			 '[name=cluster] option:selected').val();
	}

	if (! (days && count && type && cluster)) {
	    alert("Please provide the project name, the number of days, " +
		  "number of nodes, and which cluster.");
	    return;
	}
	console.info("FindFit: ", days, count, type, cluster);

	/*
	 * Slightly cheesy way to wait for the cluster data to come in.
	 */
	if (forecasts[cluster] === undefined) {
	    sup.ShowWaitWait("Waiting for cluster reservation data");
	    var waitfordata = function() {
		if (forecasts[cluster] !== undefined) {
		    sup.HideWaitWait();
		    FindFit();
		    return;
		}
		setTimeout(function() { waitfordata() }, 200);
	    };
	    setTimeout(function() { waitfordata() }, 200);
	    return;
	}
	var starttime = null;
	var startdata = null;
	var enddata   = null;

	var tmp = forecasts[cluster][type].slice(0);
	while (tmp.length && starttime == null) {
	    var data = tmp.shift();

	    if (data.free >= count) {
		starttime = data.t;
		startdata = data;

		for (var i = 0; i < tmp.length; i++) {
		    var next = tmp[i];

		    if (starttime + (3600 * 24 * days) + 3600 < next.t) {
			// The next time stamp is beyond the days requested,
			// so it fits.
			enddata = next;
			break;
		    }
		    if (next.free >= count) {
			// The next time stamp still has enough nodes,
			// keep checking.
			continue;
		    }
		    // Otherwise, we no longer fit, need to start over.
		    starttime = null;
		    break;
		}
	    }
	}
	if (starttime == null) {
	    return;
	}
	// enddata can be null if we fit on the last timeline entry.
	console.info("FindFit: ", startdata, enddata);

	var start = moment(starttime * 1000);
	/*
	 * Need to push out the start to the top of hour.
	 */
	var minutes = (start.hours() * 60) + start.minutes();
	start.hour(Math.ceil(minutes / 60));

	/*
	 * Try to shift the reservation from the middle of the night.
	 * It is okay if we cannot do this, we still want to give the
	 * user the earliest possible reservation.
	 */
	if (start.hour() < IDEAL_STARTHOUR) {
	    var tmp = moment(start);
	    tmp.hour(IDEAL_STARTHOUR);

	    // If no enddata then we can definitely shift it.
	    if (!enddata || tmp.unix() + ((3600 * 24 * days)) < enddata.t) {
		console.info("Shifting to later start time");
		start = tmp;
	    }
	}
	var end = moment(start.valueOf() + ((3600 * 24 * days) * 1000));

	var start_day  = $('#reserve-request-form [name=start_day]').val();
	var start_hour = $('#reserve-request-form [name=start_hour]').val();
	var end_day    = $('#reserve-request-form [name=end_day]').val();
	var end_hour   = $('#reserve-request-form [name=end_hour]').val();
	var new_start_day  = start.format("MM/DD/YYYY");
	var new_start_hour = start.format("H");
	var new_end_day    = end.format("MM/DD/YYYY");
	var new_end_hour   = end.format("H");

	$('#reserve-request-form [name=start_day]').val(new_start_day);
	$('#reserve-request-form [name=start_hour]').val(new_start_hour);
	$('#reserve-request-form [name=end_day]').val(new_end_day);
	$('#reserve-request-form [name=end_hour]').val(new_end_hour);

	// And if we actually changed anything.
	if (start_day != new_start_day || start_hour != new_start_hour ||
	    end_day != new_end_day || end_hour != new_end_hour) {
	    ToggleSubmit(true, "check");
	    aptforms.MarkFormUnsaved();
	}
    }

    //
    // Validate the reservation. 
    //
    function ValidateReservation()
    {
	var callback = function(json) {
	    console.info(json);
	    // Three indicates success but needs admin approval.
	    if (json.code) {
		if (json.code != 2) {
		    sup.SpitOops("oops", json.value);		    
		}
		aptforms.GenerateFormErrors('#reserve-request-form',
					    json.value);		
		// Make sure we still warn about an unsaved form.
		aptforms.MarkFormUnsaved();
		return;
	    }
	    // User can submit.
	    ToggleSubmit(true, "submit");
	    // Make sure we still warn about an unsaved form.
	    aptforms.MarkFormUnsaved();
	    if (json.value.approved == 0) {
		$('#confirm-reservation .needs-approval')
		    .removeClass("hidden");
	    }
	    else {
		$('#confirm-reservation .needs-approval')
		    .addClass("hidden");
	    }
	    sup.ShowModal('#confirm-reservation');
	};
	aptforms.SubmitForm('#reserve-request-form', "reserve",
			    "Validate", callback,
			    "Checking to see if your request can be "+
			    "accommodated");
    }

    /*
     * And do it.
     */
    function Reserve()
    {
	var reserve_callback = function(json) {
	    console.info(json);
	    if (json.code) {
		sup.SpitOops("oops", json.value);
		return;
	    }
	    if (!json.value.approved && _.has(json.value, "url")) {
		window.location.replace(json.value.url);
	    }
	    else {
		window.location.replace("list-reservations.php");
	    }
	};
	aptforms.SubmitForm('#reserve-request-form', "reserve",
			    "Reserve", reserve_callback,
			    "Submitting your reservation request; "+
			    "patience please");
    }

    /*
     * Approve a reservation
     */
    function Approve()
    {
	var callback = function (json) {
	    sup.HideModal('#waitwait-modal');
	    if (json.code) {
		sup.SpitOops("oops", json.value);
		return;
	    }
	    window.location.reload(true);
	};
	// Bind the confirm button in the modal. Do the approval.
	$('#approve-modal #confirm-approve').click(function () {
	    sup.HideModal('#approve-modal', function () {
		var message = $('#approve-modal .user-message').val().trim();
		sup.ShowModal('#waitwait-modal');
		var xmlthing = sup.CallServerMethod(null, "reserve",
						    "Approve",
						    {"cluster" : window.CLUSTER,
						     "uuid"    : window.UUID,
						     "type"    : "reservation",
						     "message" : message});
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

    function PopulateReservation()
    {
	var callback = function(json) {
	    console.log("PopulateReservation", json);
	    sup.HideWaitWait();
	    if (json.code) {
		sup.SpitOops("oops", json.value);
		return;
	    }
	    // Messy.
	    var details = json.value;
	    $('#reserve-request-form [name=uuid]').val(details.uuid);
	    $('#reserve-request-form [name=pid]').val(details.pid);
	    $('#reserve-request-form [name=count]').val(details.nodes);
	    $('#reserve-request-form [name=cluster]').val(details.cluster_urn);
	    $('#reserve-request-form [name=cluster_id]').val(details.cluster_id);
	    $('#reserve-request-form [name=type]').val(details.type);
	    $('#reserve-request-form [name=reason]').val(details.notes);
	    var start = moment(details.start);
	    var end = moment(details.end);	
	    $('#reserve-request-form [name=start_day]')
		.val(start.format("MM/DD/YYYY"));
	    $('#reserve-request-form [name=start_hour]')
		.val(start.format("H"));
	    $('#reserve-request-form [name=end_day]')
		.val(end.format("MM/DD/YYYY"));
	    $('#reserve-request-form [name=end_hour]')
		.val(end.format("H"));
	    var hours = end.diff(start, "hours");
	    var days  = hours / 24;
	    $('#reserve-request-form [name=days]')
		.val(days.toFixed(1));

	    //console.log(start, end);

	    /*
	     * Need this in case the start date is in the past.
	     */
	    $("#reserve-request-form #start_day")
		.datepicker("option", "minDate", start.format("MM/DD/YYYY"));

	    // Set the hour selectors properly in the datepicker object.
	    $("#reserve-request-form #start_day")
		.datepicker("setDate", start.format("MM/DD/YYYY"));
	    $("#reserve-request-form #end_day")
		.datepicker("setDate", end.format("MM/DD/YYYY"));

	    if (details.approved) {
		$('#unapproved-warning').addClass("hidden");
	    }
	    else {
		$('#unapproved-warning').removeClass("hidden");
	    }
	    // Local user gets a link.
	    if (_.has(details, 'uid_idx')) {
		$('#reserve-requestor').html(
		    "<a target=_blank href='user-dashboard.php?user=" +
			details.uid_idx + "'>" +
			details.uid + "</a>");
	    }
	    else {
		$('#reserve-requestor').html(details.uid);
	    }
	    
	    /*
	     * If this is an admin looking at an unapproved reservation,
	     * show the approve button
	     */
	    if (isadmin && !details.approved) {
		$('#reserve-approve-button').removeClass("hidden");
		$('#reserve-approve-button').click(function(event) {
		    event.preventDefault();
		    Approve();
		});
	    }
	    // Need this in Delete().
	    window.PID = details.pid;
	    // Now enable delete button
	    $('#reserve-delete-button').removeAttr("disabled");

	    // Now we can load the graph since we know the project.
	    LoadReservations(details.pid);

	    // Add append history graph under the reservation graph.
	    DrawHistoryGraph(details);
	};
	sup.ShowWaitWait();
	var xmlthing = sup.CallServerMethod(null, "reserve",
					    "GetReservation",
					    {"cluster" : window.CLUSTER,
					     "uuid"    : window.UUID});
	xmlthing.done(callback);
    }

    /*
     * Delete a reservation
     */
    function Delete()
    {
	var callback = function(json) {
	    sup.HideWaitWait();
	    if (json.code) {
		sup.SpitOops("oops", json.value);
		return;
	    }
	    window.location.replace("list-reservations.php");
	};

	// Bind the confirm button in the modal. Do the deletion.
	$('#delete-reservation-modal #confirm-delete').click(function () {
	    sup.HideModal('#delete-reservation-modal', function () {
		var reason  = $('#delete-reason').val();
		sup.ShowModal('#waitwait-modal');
		var xmlthing = sup.CallServerMethod(null, "reserve",
						    "Delete",
						    {"cluster" : window.CLUSTER,
						     "uuid"    : window.UUID,
						     "pid"     : window.PID,
						     "type"    : "reservation",
						     "reason"  : reason});
		xmlthing.done(callback);
	    });
	});
	
	// Handler so we know the user closed the modal. We need to
	// clear the confirm button handler.
	$('#delete-reservation-modal').on('hidden.bs.modal', function (e) {
	    $('#delete-reservation-modal #confirm-delete').unbind("click");
	    $('#delete-reservation-modal').off('hidden.bs.modal');
	})
	sup.ShowModal("#delete-reservation-modal");
    }

    function HandleClusterChange(selected_cluster)
    {
	/*
	 * Build up selection list of types on the selected cluster
	 */
	var options  = "";
	var typelist = amlist[selected_cluster].typeinfo;
	var nodelist = amlist[selected_cluster].reservable_nodes;
	var nickname = amlist[selected_cluster].nickname;
	var id       = "resgraph-" + nickname;

	_.each(typelist, function(details, type) {
	    var count = details.count;
	    
	    options = options +
		"<option value='" + type + "' >" +
		type + " (" + count + " nodes)</option>";
	});
	_.each(nodelist, function(details, node_id) {
	    options = options +
		"<option value='" + node_id + "' >" + node_id + "</option>";
	});
	
	$("#reserve-request-form #type")	
	    .html("<option value=''>Please Select</option>" + options);

	if ($('#reservation-lists :first-child').attr("id") != id) {
	    $('#' + id).fadeOut("fast", function () {
		$('#reservation-lists').prepend($('#' + id));
		$('#' + id).fadeIn("fast");
	    });
	}
    }

    function HandleTypeChange()
    {
	var selected_cluster =
	    $("#reserve-request-form #cluster option:selected").val();
	var selected_type =
	    $("#reserve-request-form #type option:selected").val();

	console.info(selected_cluster, selected_type);
	if (selected_cluster == "") {
	    return;
	}
	if (selected_type == "") {
	    return;
	}
	var nodelist = amlist[selected_cluster].reservable_nodes;
	console.info(nodelist);

	if (_.has(nodelist, selected_type)) {
	    $("#reserve-request-form #count").val("1");
	    $("#reserve-request-form #count").prop("readonly", true);	    
	}
	else {
	    $("#reserve-request-form #count").val("");
	    $("#reserve-request-form #count").prop("readonly", false);
	}
    }

    // Toggle the button between check and submit.
    function ToggleSubmit(enable, which) {
	if (which == "submit") {
	    $('#reserve-submit-button').text("Submit");
	    $('#reserve-submit-button').addClass("btn-success");
	    $('#reserve-submit-button').removeClass("btn-primary");
	}
	else if (which == "check") {
	    $('#reserve-submit-button').text("Check");
	    $('#reserve-submit-button').removeClass("btn-success");
	    $('#reserve-submit-button').addClass("btn-primary");
	    if (editing) {
		$('#reserve-approve-button').attr("disabled", "disabled");
	    }
	}
	if (enable) {
	    $('#reserve-submit-button').removeAttr("disabled");
	}
	else {
	    $('#reserve-submit-button').attr("disabled", "disabled");
	}
	buttonstate = which;
    }

    // Draw the history bar graph.
    function DrawHistoryGraph(details)
    {
	if (!_.has(details, 'history') || !details.history.length) {
	    return;
	}
	var graphid = "history-graph";
	var html = usageTemplate({"graphid"        : graphid,
				  "showfullscreen" : true});
	
	$('#reservation-lists').append(html);
	window.DrawResHistoryGraph({"details"  : details,
				    "graphid"  : '#' + graphid});

	// Setup a handler to draw the large version graph in the modal.
	$('#resusage-modal').on('shown.bs.modal', function() {
	    window.DrawResHistoryGraph({"details"    : details,
					"graphid"    : '#resusage-modal',
					"xaxislabel" : true});
	});
	// When modal shows, we draw.
	$('#' + graphid + ' .resusage-fullscreen').click(function (event) {
	    // Make sure nothing left behind.
	    $('#resusage-modal svg').html("");
	    sup.ShowModal('#resusage-modal', function () {
		// Need to unbind the hook above.
		$('#resusage-modal').off('shown.bs.modal');
	    });
	});
    }
    $(document).ready(initialize);
});
