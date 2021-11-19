$(function ()
{
    'use strict';

    var templates = APT_OPTIONS.fetchTemplateList(['adminextend', 'waitwait-modal', 'oops-modal', 'admin-history', 'admin-firstrow', 'admin-secondrow', 'admin-utilization', 'admin-summary', "reservation-list"]);
    var mainString = templates['adminextend'];
    var waitwaitString = templates['waitwait-modal'];
    var oopsString = templates['oops-modal'];
    var historyString = templates['admin-history'];
    var firstrowString = templates['admin-firstrow'];
    var secondrowString = templates['admin-secondrow'];
    var utilizationString = templates['admin-utilization'];
    var summaryString = templates['admin-summary'];

    var expinfo            = null;
    var extensions         = null;
    var firstrowTemplate   = null;
    var secondrowTemplate  = null;
    var extensionsTemplate = null;
    var listTemplate       = null;
    var maxextension       = null;
    var GENIRESPONSE_REFUSED = 7;

    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);

	$('#main-body').html(mainString);
	$('#waitwait_div').html(waitwaitString);
	$('#oops_div').html(oopsString);

	firstrowTemplate = _.template(firstrowString);
	secondrowTemplate = _.template(secondrowString);
	extensionsTemplate = _.template(historyString);
	listTemplate = _.template(templates["reservation-list"]);

	ReloadFirstRow();
	LoadResGroups();
	if (window.STARTED) {
	    $('#extension-controls').removeClass("hidden");
	    LoadIdleData();
	    LoadUtilization();
	    LoadOpenStack();
	}

	// Second row is the user/project usage summarys. We make two calls
	// and use jquery "when" to wait for both to finish before running
	// the template.
	var xmlthing1 = sup.CallServerMethod(null, "user-dashboard",
					     "UsageSummary",
					     {"uid"    : window.CREATOR});
	var xmlthing2 = sup.CallServerMethod(null, "show-project",
					     "UsageSummary",
					     {"pid"    : window.PID});
	$.when(xmlthing1, xmlthing2).done(function(result1, result2) {
	    console.info(result1, result2);
	    var html = secondrowTemplate({"uid"     : window.CREATOR,
					  "pid"     : window.PID,
					  "uuid"    : window.UUID,
					  "user"    : result1.value,
					  "project" : result2.value});
	    $("#secondrow").html(html);
	});

	// The extension details in a collapse panel.
	if ($('#extensions-json').length) {
	    extensions = decodejson('#extensions-json');
	    console.info(extensions);

	    var html = extensionsTemplate({"extensions" : extensions});
	    $("#history-panel-content").html(html);
	    $("#history-panel-div").removeClass("hidden");

	    // Scroll to the bottom does not appear to work until the div
	    // is actually expanded.
	    $('#history-collapse').on('shown.bs.collapse', function () {
		$("#history-panel-content").scrollTop(10000);
	    });
	}
	if ($('#extension-reason').length) {
	    $("#extension-reason-row pre").text($('#extension-reason').text());
	    $("#extension-reason-row").removeClass("hidden");
	}
	// This activates the popover subsystem.
	$('#history-panel-content [data-toggle="popover"]').popover({
	    trigger: 'hover',
	    placement: 'auto',
	});
	// Extension metrics handler, to show in modal
	$('#history-panel-content .autoapprove-metrics').click(function (e) {
	    e.preventDefault();
	    ShowMetricsModal(this);
	});
	
	// Default number of days.
	if (window.HOURS) {
	    $('#howlong').val(convertHours(window.HOURS));
	}
	// Handlers for Extend and Deny buttons.
	$('#deny-extension').click(function (event) {
	    event.preventDefault();
	    Action("deny");
	    return false;
	});
	$('#do-extension').click(function (event) {
	    event.preventDefault();
	    Action("extend");
	    return false;
	});
	$('#do-moreinfo').click(function (event) {
	    event.preventDefault();
	    Action("moreinfo");
	    return false;
	});
	$('#do-terminate').click(function (event) {
	    event.preventDefault();
	    sup.HideModal("#confirm-terminate-modal");
	    Action("terminate");
	    return false;
	});
	/*
	 * Handler for the Maximum Extension button, which just overwrites
	 * the value in the input box. We want to save off the current
	 * value to restore if later unchecked.
	 */
	var current_extension_input = null;
	$('#maximum-extension-checkbox').change(function (e) {
	    if ($('#maximum-extension-checkbox').is(":checked")) {
		current_extension_input = $('#howlong').val();
		if (maxextension == null) {
		    alert("There is no maximum extension!");
		    // Flip the checkbox back.
		    $('#maximum-extension-checkbox').prop("checked", false);
		    return;
		}
		// Kill the input field, it will be ignored.
		$('#howlong').val("");
		// And make it read only to make it clear.
		$('#howlong').prop("readonly", true);
	    }
	    else {
		$('#howlong').val(current_extension_input);
		$('#howlong').prop("readonly", false);
	    }
	});
    }

    //
    // Convert xDyH into hours. A plain integer is just days.
    //
    function getHowlong()
    {
	var howlong = $.trim($('#howlong').val());

	// Nothing means zero.
	if (howlong == "") {
	    return 0;
	}

	var matches = howlong.match(/^(\d+)(D|H)?$/i);
	if (matches) {
	    if (matches[2] === undefined ||
		matches[2] == "D" || matches[2] == "d") {
		return parseInt(matches[1]) * 24;
	    }
	    return parseInt(matches[1]);
	}
	matches = howlong.match(/^(\d+)D(\d+)H$/i);
	if (matches) {
	    return (parseInt(matches[1]) * 24) + parseInt(matches[2]);
	}
	return undefined;
    }
    function convertHours(hours)
    {
        /*
         * Convert hours to handy 5D14H string or just days integer.
         */
	var days  = parseInt(hours / 24);
	var hours = hours % 24;
	var str;

        if (days) {
	    if (!hours) {
		return days;
	    }
	    return days + "D" + hours + "H";
        }
	return hours + "H";
    }

    //
    // Do the extension.
    //
    function Action(action)
    {
	var howlong = getHowlong();
	var reason  = $("#reason").val();
	var method  = (action == "extend" ?
		       "RequestExtension" :
		       (action == "moreinfo" ?
			"MoreInfo" :
			(action == "terminate" ?
			 "SchedTerminate" : "DenyExtension")));
	// Only an extend option.
	var force = 0;
	if (action == "extend" &&
	    $('#force-extension-checkbox').is(":checked")) {
	    force = 1;
	}
	// Extend out to currently allowed maximum extension.
	if (action == "extend" &&
	    $('#maximum-extension-checkbox').is(":checked")) {
	    howlong = maxextension.toString();
	}
	else if (howlong === undefined) {
	    alert("Cannot parse extension duration");
	    return;
	}
	var lockout = 0;
	if ((action == "deny" || action == "terminate") &&
	    $('#deny-lockout-checkbox').is(":checked")) {
	    lockout = 1;
	}
	var callback = function(json) {
	    sup.HideModal("#waitwait-modal");

	    if (json.code) {
		var message;
		
		if (json.code < 0) {
		    message = "Operation failed!";
		}
		else {
		    message = "Operation failed: " + json.value;
		}
		sup.SpitOops("oops", message);
		return;
	    }
	    // Must change this so that reloading maxextension does not
	    // throw a hissy fit.
	    if (window.HOURS) {
		window.HOURS = window.HOURS - howlong;
	    }
	    ReloadFirstRow();
	    // Make it harder to repeat action unintentionally. 
	    if (action == "extend" || action == "terminate") {
		$('#howlong').val("0");
	    }
	    sup.ShowModal("#success-modal");
	};
	sup.ShowModal("#waitwait-modal");
	var xmlthing = sup.CallServerMethod(null, "status", method,
					    {"uuid"   : window.UUID,
					     "howlong": howlong,
					     "reason" : reason,
					     "force"  : force,
					     "lockout": lockout});
	xmlthing.done(callback);	
    }

    // First Row is the experiment summary info.
    function LoadFirstRow() {
	var html = firstrowTemplate(
	    {"expinfo" : expinfo,
	     "uuid"    : window.UUID,
	     "uid"     : window.CREATOR,
	     "pid"     : window.PID}
	);
	$("#firstrow").html(html);
	$('.format-date').each(function() {
	    var date = $.trim($(this).html());
	    if (date != "") {
		$(this).html(moment(date)
			     .format("MMM D, YYYY h:mm A"));
	    }
	});
	if (!window.STARTED) {
	    // Disable the flags. 
	    $('#lockout-checkbox, #user-lockdown-checkbox, ' +
	      '#admin-lockdown-checkbox, #quarantine-checkbox')
		.attr("disabled", "disabled");
	}
	else {
	    // lockout change event handler.
	    $('#lockout-checkbox').change(function() {
		DoLockout($(this).is(":checked"));
	    });	
	    // lockdown change event handler.
	    $('#user-lockdown-checkbox')
		.change(function() {
		    DoLockdown("user",
			       $(this).is(":checked"));
		});
	    $('#admin-lockdown-checkbox')
		.change(function() {
		    DoLockdown("admin",
			       $(this).is(":checked"));
		});
	    $('#quarantine-checkbox')
		.change(function() {
		    DoQuarantine($(this).is(":checked"));
		});
	}
	// This activates the popover subsystem.
	$('[data-toggle="popover"]').popover({
	    trigger: 'hover',
	    placement: 'auto',
	});
	// No termination.
	if (expinfo.admin_lockdown) {
	    $('#terminate-button')
		.attr("disabled", "disabled");
	}
	// Update the Max Extension
	DoMaxExtension(expinfo.expires);
	SetupAdminNotes();
    }
    
    function ReloadFirstRow()
    {
	sup.CallServerMethod(null, "status", "ExpInfo",
			     {"uuid" : window.UUID},
			     function (json) {
				 console.info(json);
				 if (json.code == 0) {
				     expinfo = json.value;
				     LoadFirstRow();
				 }
			     });
    }

    function LoadUtilization() {
	if (!window.STARTED) {
	    return;
	}
	var utilizationTemplate = _.template(utilizationString);
	var summaryTemplate = _.template(summaryString);
	
	var callback = function(json) {
	    console.info("LoadUtilization", json);
	    if (json.code) {
		console.info("Could not load utilization");
		$("#thirdrow .thirdrow-error .well")
		    .html("Could not get summary/utilization data: " +
			  json.value);
		$("#thirdrow .thirdrow-error").removeClass("hidden");
		return;
	    }
	    var html = utilizationTemplate({"utilization" : json.value});
	    $("#utilization-panel-content").html(html);
	    InitTable("utilization");
	    $("#utilization-panel-div").removeClass("hidden");

	    var html = summaryTemplate({"utilization" : json.value});
	    $("#thirdrow").html(html);

	    // This activates the tooltip subsystem.
	    $('[data-toggle="tooltip"]').tooltip({
		delay: {"hide" : 500, "show" : 150},
		placement: 'auto',
	    });
	};
	var xmlthing = sup.CallServerMethod(null, "status", "Utilization",
					    {"uuid"   : window.UUID});
	xmlthing.done(callback);	
    }
    function InitTable(name)
    {
	var tablename  = "#" + name + "-table";
	
	var table = $(tablename)
		.tablesorter({
		    theme : 'bootstrap',
		    // initialize zebra and filter widgets
		    widgets: ["uitheme"],
		    headerTemplate : '{content} {icon}',
		});
    }

    //
    // Request lockout set/clear.
    //
    function DoLockout(lockout)
    {
	lockout = (lockout ? 1 : 0);

	var callback = function(json) {
	    if (json.code) {
		alert("Failed to change lockout: " + json.value);
		// Flip the checkbox back
		$('#lockout-checkbox').prop("checked", false);
		return;
	    }
	}
	if (lockout) {
	    // So we can clear the checkbox if user cancels the modal.
	    var confirmed = 0;
	    
	    // Bind the confirm button in the modal. 
	    $('#disable-extension-modal .confirm-button').click(function () {
		confirmed = 1;
		sup.HideModal('#disable-extension-modal', function () {
		    var reason  = $('#disable-extension-modal .reason').val();
		    var xmlthing = sup.CallServerMethod(null,
							"status", "Lockout",
							{"uuid"   : window.UUID,
							 "lockout": lockout,
							 "reason" : reason});
		    xmlthing.done(callback);
		});
	    });
	    // Handler so we know the user closed the modal. We need to
	    // clear the confirm button handler.
	    $('#disable-extension-modal').on('hidden.bs.modal', function (e) {
		$('#disable-extension-modal .confirm-button').unbind("click");
		$('#disable-extension-modal').off('hidden.bs.modal');
		if (!confirmed) {
		    // Flip the checkbox back
		    $('#lockout-checkbox').prop("checked", false);
		}
	    });
	    sup.ShowModal("#disable-extension-modal");
	    return;
	}
	// Clearing the lockout.
	var xmlthing = sup.CallServerMethod(null, "status", "Lockout",
					     {"uuid" : window.UUID,
					      "lockout" : lockout});
	xmlthing.done(callback);
    }

    //
    // Request lockdown set/clear.
    //
    function DoLockdown(which, lockdown, force)
    {
	var action = (lockdown ? "set" : "clear");
	// Optional arg.
	if (force === undefined) {
	    force = 0;
	}
	
	var callback = function(json) {
	    if (json.code) {
		sup.HideModal("#waitwait-modal", function () {
		    if (lockdown) {
			// Flip the checkbox back.
			$('#' + which + '-lockdown-checkbox')
			    .prop("checked", false);
		    }
		    else {
			// Flip the checkbox back.
			$('#' + which + '-lockdown-checkbox')
			    .prop("checked", true);
		    }
		    if (json.code != GENIRESPONSE_REFUSED) {
			sup.SpitOops("oops",
				     "Lockdown failed: " + json.value);
			return;
		    }
		    // Refused.
		    $('#force-lockdown').click(function (event) {
			sup.HideModal('#lockdown-refused', function() {
			    // Flip the checkbox again
			    $('#' + which + '-lockdown-checkbox')
				.prop("checked", true);
			    // Again with force.
			    DoLockdown(which, lockdown, 1);
			});
		    });
		    $('#lockdown-refused pre').text(json.value);
		    sup.ShowModal('#lockdown-refused', function () {
			$('#force-lockdown').off("click");
		    });
		});
		return;
	    }
	    sup.HideModal("#waitwait-modal");
	    if (which == "admin") {
		if (lockdown) {
		    $('#terminate-button').attr("disabled", "disabled");
		}
		else {
		    $('#terminate-button').removeAttr("disabled");
		}
	    }
	}
	sup.ShowModal("#waitwait-modal");
	var xmlthing = sup.CallServerMethod(null, "status", "Lockdown",
					    {"uuid"   : window.UUID,
					     "which"  : which,
					     "action" : action,
					     "force"  : force});
	xmlthing.done(callback);
    }

    //
    // Request panic mode set/clear.
    //
    function DoQuarantine(mode)
    {
	mode = (mode ? "set" : "clear");

	var callback = function(json) {
	    if (json.code) {
		sup.HideModal('#waitwait-modal', function () {
		    sup.SpitOops("oops",
				 "Failed to change Quarantine mode: " +
				 json.value);
		    if (mode) {
			// Flip the checkbox back.
			$('#quarantine-checkbox')
			    .prop("checked", false);
		    }
		    else {
			// Flip the checkbox back.
			$('#quarantine-checkbox')
			    .prop("checked", true);
		    }
		});
		return;
	    }
	    sup.HideModal('#waitwait-modal');
	}
	// Handler for hide modal, this is the cancel operation.
	$('#confirm-quarantine-modal').on('hidden.bs.modal', function (event) {
	    $(this).unbind(event);
	    $('#confirm-quarantine').unbind("click.quarantine");
	    if (mode) {
		// Flip the checkbox back.
		$('#quarantine-checkbox')
		    .prop("checked", false);
	    }
	    else {
		// Flip the checkbox back.
		$('#quarantine-checkbox')
		    .prop("checked", true);
	    }
	});
	// Handler for the confirm button,
	$('#confirm-quarantine').bind("click.quarantine", function (event) {
	    // Unbind the handlers.
	    $('#confirm-quarantine').unbind("click.quarantine");
	    $('#confirm-quarantine-modal').off('hidden.bs.modal');
	    
	    sup.HideModal('#confirm-quarantine-modal', function () {
		var args = {"uuid" : window.UUID,
			    "quarantine" : mode};
		if (mode &&
		    $('#quarantine-poweroff-checkbox').is(":checked")) {
		    args["poweroff"] = 1;
		}
		sup.ShowModal('#waitwait-modal');
		var xmlthing = sup.CallServerMethod(null, "status",
						    "Quarantine", args);
		xmlthing.done(callback);
	    });
	});
	if (mode) {
	    $('#confirm-quarantine-modal .q-on').removeClass("hidden");
	    $('#confirm-quarantine-modal .q-off').addClass("hidden");
	}
	else {
	    $('#confirm-quarantine-modal .q-on').addClass("hidden");
	    $('#confirm-quarantine-modal .q-off').removeClass("hidden");
	}
	sup.ShowModal('#confirm-quarantine-modal');
    }

    //
    // Get Max Extension and update the table.
    //
    function DoMaxExtension(expires)
    {
	console.info("DoMaxExtension", expires);

	if (! window.STARTED) {
	    $('#max-extension').html("<span class='text-warning'>" +
				     "Not Started Yet</span>");	    
	    return;
	}
	
	// Warn if changing days violates max extension.
	var callback = function(json) {
	    $("#howlong").on("keyup", function (event) {
		if (!maxextension) {
		    $('#max-extension-nomax').removeClass("hidden");
		    return;
		}
		$('#max-extension-nomax').addClass("hidden");
		var hours = getHowlong();
		console.info("getHowlong returns ", hours);
		if (hours !== undefined) {
		    if (hours) {
			var when = moment(expires).add(hours, "hours");
			console.info("when", when.format('lll'));
			console.info("max", maxextension.format('lll'));
			if (when.isAfter(maxextension)) {
			    $('#max-extension-warning .max-extension-date')
				.html(when.format('lll'));
			    $('#max-extension-warning').removeClass("hidden");
			}
			else {
			    $('#max-extension-warning').addClass("hidden");
			    $('#max-extension-warning .max-extension-date')
				.html("");
			}
			return;
		    }
		}
		$('#max-extension-warning').addClass("hidden");
		$('#max-extension-warning .max-extension-date').html("");
	    });
	    console.info("DoMaxExtension: ", json);
	    
	    if (json.code) {
		console.info("Failed to get max extension", json);
		$('#howlong').val("0");
		$('#max-extension-nomax').removeClass("hidden");
		
		/*
		 * Special case, the cluster is saying no extension is possible,
		 * so it does not even provide a date.
		 */
		if (json.code == GENIRESPONSE_REFUSED) {
		    $('#max-extension').html("<span class='text-danger'>" +
					     "No Extension Possible!</span>");
		    if (window.DAYS) {
			alert("The cluster says no extension is possible at all! " +
			      "Granting any extension can potentially throw the " +
			      "reservation system into overbook.");
		    }
		}
		else {
		    $('#max-extension').html("<span class='text-danger'>" +
					     "Cannot Get Max Extension!</span>");
		    alert("Unable to get the maximum allowed extension from " +
			  "the cluster. " +
			  "Granting any extension can potentially throw the " +
			  "reservation system into overbook.");
		}
		return;
	    }
	    // Save for checking the extension input field.
	    maxextension = moment(json.value.maxextension);
	    
	    $('#max-extension')
		.html(maxextension.format("MMM D, YYYY h:mm A"));
	    
	    /*
	     * Look to see if the number of hours requested is going to be
	     * greater then the max slice extension. If it is, then we want
	     * to make sure that is noticed.
	     */
	    if (window.HOURS) {
		var exp = new Date(expires);
		var max = new Date(json.value.maxextension);
		exp.setTime(exp.getTime() + window.HOURS * 3600 * 1000);
	    
		if (exp.getTime() > max.getTime()) {
		    var m1   = moment(exp.getTime());
		    var m2   = moment(max.getTime());
		    var diff = m1.diff(m2, "hours");

		    var d = parseInt(diff / 24);
		    var h = diff % 24;
		    var str;

		    if (d) {
			str = d + "days";
			if (h) {
			    str = str + "and " + h + " hours";
			}
		    }
		    else {
			str = d + "hours";
		    }
		    alert("Granting this full extension would violate the " +
			  "current maximum allowed extension by " + str + ". " +
			  "Granting the extension can potentially throw the " +
			  "reservation system into overbook.");

		    // Change the box number to reflect a legal extension.
		    if (window.HOURS >= diff) {
			$('#howlong').val(convertHours(window.HOURS - diff));
		    }
		    else {
			$('#howlong').val("0");
		    }
		}
	    }
	}
	var xmlthing = sup.CallServerMethod(null, "status", "MaxExtension",
					    {"uuid" : window.UUID});
	xmlthing.done(callback);
    }

    //
    // Slothd graphs.
    //
    function LoadIdleData()
    {
	var callback = function (status, json) {
	    if (status <= 0) {
		if (status == 0) {
		    // No data.
		    $('#idledata-nodata').removeClass("hidden");
		}
		else {
		    // Error, show something that indicates we could not get
		    // the idle data.
		    $('#idledata-error').html("Could not get graph data: " +
					      json.value);
		    $('#idledata-error').removeClass("hidden");
		}
	    }
	};
	ShowIdleGraphs({"uuid"     : window.UUID,
			"showwait" : false,
			"loadID"   : "#loadavg-panel-div",
			"ctrlID"   : "#ctrl-traffic-panel-div",
			"exptID"   : "#expt-traffic-panel-div",
			"callback" : callback});
    }

    //
    // Openstacks stats.
    //
    function LoadOpenStack()
    {
	var callback = function(json) {
	    if (json.code) {
		return;
	    }
	    // Might not be any.
	    if (!json.value || json.value == "") {
		return;
	    }
	    var html = "<pre>" + json.value + "</pre>";
	    $("#openstack-panel-div").removeClass("hidden");
	    $("#openstack-panel-content").html(html);
	};
    	var xmlthing = sup.CallServerMethod(null, "status", "OpenstackStats",
					    {"uuid" : window.UUID});
	xmlthing.done(callback);
    }

    //
    // Setup the admin notes panel for editing
    //
    function SetupAdminNotes()
    {
	var modified = 0;
	var notes = $.trim($("#adminnotes-collapse textarea").val());
	
	// Panel starts out collapsed.
	$('#adminnotes-collapse').on('show.bs.collapse', function () {
	    $('#adminnotes-row .toggle').html('Hide');
	});
	$('#adminnotes-collapse').on('hide.bs.collapse', function () {
	    var label = "View";
	    if ($("#adminnotes-collapse textarea").val() == "") {
		label = "Add";
	    }
	    $('#adminnotes-row .toggle').html(label);
	});
	$("#adminnotes-collapse textarea")
	    .on("change input paste keyup", function() {
		modified = 1;
		$('#adminnotes-save-button').removeClass('hidden');
	    });
	$('#adminnotes-save-button').click(function (event) {
	    event.preventDefault();
	    if (modified) {
		SaveAdminNotes(function () {
		    modified = 0;
		    $('#adminnotes-save-button').addClass('hidden');
		});
	    }
	});
	if (notes != "") {
	    $('#adminnotes-collapse').collapse('show');	    
	}
    }
    function SaveAdminNotes(done)
    {
	var notes = $("#adminnotes-collapse textarea").val();
	
	var callback = function(json) {
	    if (json.code) {
		sup.SpitOops("oops", "Failed to save admin notes: " +
			     json.value);
		return;
	    }
	    done();
	};
    	var xmlthing = sup.CallServerMethod(null, "status", "SaveAdminNotes",
					    {"uuid"  : window.UUID,
					     "notes" : notes});
	xmlthing.done(callback);
    }
    function ShowMetricsModal(target)
    {
	var idx = $(target).data("idx");
	var str = extensions[idx].autoapproved_metrics;
	str.replace(/\\"/g, '"');
	var obj = JSON.parse(str);
	str = JSON.stringify(obj, null, 2); 
	console.info(str);
	$('#metrics-content').text(str);
	sup.ShowModal('#metrics-modal');
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

	// Say something informative in the panel header.
	$('#resusage-graph-modal .resusage-graph-details')
	    .html("(" + details.nodes + " " + details.type + " nodes)");
	
	sup.ShowModal('#resusage-graph-modal', function () {
	    // Need to unbind the hook above.
	    $('#resusage-graph-modal').off('shown.bs.modal');
	});
    }

    /*
     * Check for existing reservations and draw the list.
     */
    function LoadResGroups()
    {
	sup.CallServerMethod(null, "resgroup", "ListReservationGroups",
			     {"project" : window.PID},
			     function (json) {
				 if (json.code) {
				     console.info(json.value);
				     return;
				 }
				 var groups = json.value;
				 if (_.size(groups)) {
				     $('#reservations-row')
					 .removeClass("hidden");
				     window.DrawResGroupList("#groups", groups);
				 }
			     });
    }
    
    // Helper.
    function decodejson(id) {
	return JSON.parse(_.unescape($(id)[0].textContent));
    }

    initialize();
});
