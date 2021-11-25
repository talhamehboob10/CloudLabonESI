$(function ()
{
    'use strict';

    var templates = APT_OPTIONS.fetchTemplateList(['powder-shutdown',
						   'waitwait-modal',
						   'oops-modal']);

    var mainString     = templates['powder-shutdown'];
    var waitwaitString = templates['waitwait-modal'];
    var oopsString     = templates['oops-modal'];
    var timerID        = null;
    var instances      = [];

    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);

	$('#page-body').html(mainString);
	$('#oops_div').html(oopsString);
	$('#waitwait_div').html(waitwaitString);

	// Setup the shutdown modal.
	$('#powder-shutdown-button').click(function (event) {
	    event.preventDefault();
	    DoShutdown();
	});
    }

    // Throw up a confirmation modal, with handler bound to confirm.
    function DoShutdown()
    {
	$('#panic-listing-div').addClass("hidden");

	// Handler for hide modal to unbind the click handler.
	$('#confirm-shutdown-modal').on('hidden.bs.modal', function (event) {
	    $(this).unbind(event);
	    $('#confirm-shutdown-button').unbind("click.shutdown");
	});

	// Confirm button.
	$('#confirm-shutdown-button').bind("click.shutdown", function (event) {
	    sup.HideModal('#confirm-shutdown-modal');

	    var callback = function(json) {
		sup.HideModal('#waitwait-modal', function () {
		    if (json.code) {
			sup.SpitOops("oops",
				     "Failed to start powder emergency stop: " +
				     + json.value);
		    }
		    else {
			ShutdownStarted(json.value);
		    }
		});
	    };
	    sup.ShowModal('#waitwait-modal');
	    var xmlthing = sup.CallServerMethod(null, "powder-shutdown",
						"Shutdown");
	    xmlthing.done(callback);
	});
	sup.ShowModal('#confirm-shutdown-modal');
    }

    // Shutdown has started, build table, then watch and update.
    function ShutdownStarted(info)
    {
	if (info.length == 0) {
	    sup.ShowModal("#noexperiments-modal");
	    return;
	}
	console.info(info);

	/*
	 * Throw up the list of experiments that are going to be
	 * shutdown.
	 */
	var html = "";
	
	_.each(info, function(value, idx) {
	    var name   = value.name;
	    var status = value.status;

	    // Remember uuid listing for updates.
	    instances.push(value.uuid);
	    
	    if (window.ISADMIN) {
		// Show a link for admins.
		name = "<a href='status.php?uuid=" + value.uuid + "' " +
		    "target=_blank>" + name + "</a>";
	    }
	    html = html +
		"<tr id='" + value.uuid + "'>" +
		" <td class='text-nowrap'>" + name + "</td>" +
		" <td class='text-nowrap'>" + value.creator + "</td>" +
		" <td class='text-nowrap format-date'>" +
		       value.created + "</td>" +
		" <td class='text-nowrap exp-status'>" + status + "</td>" +
		" <td class='text-nowrap'>" + value.clusters + "</td>" +
		"</tr>";
	});
	$('#experiments-table tbody').html(html);

	// Format dates with moment before display.
	$('.format-date').each(function() {
	    var date = $.trim($(this).html());
	    if (date != "") {
		$(this).html(moment($(this).html()).format("ll"));
	    }
	});
	$('#experiments-table').tablesorter({
	    theme : 'bootstrap',
	    widgets : [ "uitheme", "zebra"],
	    headerTemplate : '{content} {icon}',
	});
	
	$('#panic-listing-div .working').removeClass("hidden");		
	$('#panic-listing-div .finished').addClass("hidden");
	$('#panic-listing-div').removeClass("hidden");
	timerID = setInterval(ShutdownWatch, 5000);
    }

    // Poll for shutdown status
    function ShutdownWatch()
    {
	var count = 0;
	
	var callback = function(json) {
	    console.info(json);
	    
	    if (json.code) {
		console.info("Failed to get new status: " + json.value);
		return;
	    }
	    _.each(json.value, function(value, idx) {
		var uuid   = value.uuid;

		if (value.paniced != 0) {
		    $('#' + uuid + " .exp-status").html(
			"<span class=text-danger>quarantined</span>");
		    count++;
		}
	    });
	    if (count == instances.length) {
		// Done!
		$('#panic-listing-div .working').addClass("hidden");		
		$('#panic-listing-div .finished').removeClass("hidden");
		clearInterval(timerID);
		timerID = null;
	    }
	};
	var xmlthing = sup.CallServerMethod(null, "powder-shutdown", "Status",
					    {"instances" : instances});
	xmlthing.done(callback);
    }

    $(document).ready(initialize);
});
