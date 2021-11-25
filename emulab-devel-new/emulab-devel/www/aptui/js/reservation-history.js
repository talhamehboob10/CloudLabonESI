$(function ()
{
    'use strict';

    var template_list   = ["reservation-history", "reservation-list",
			   "resusage-graph", "oops-modal", "waitwait-modal"];
    var templates       = APT_OPTIONS.fetchTemplateList(template_list);    
    var mainTemplate    = _.template(templates["reservation-history"]);
    var listTemplate    = _.template(templates["reservation-list"]);
    var graphTemplate   = _.template(templates["resusage-graph"]);
    var oopsString      = templates["oops-modal"];
    var waitwaitString  = templates["waitwait-modal"];
    var amlist = null;
    
    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);
	amlist  = decodejson('#amlist-json');

	$('#main-body').html(mainTemplate({"amlist" : amlist,
					   "uid"    : window.UID}));
	$('#oops_div').html(oopsString);	
	$('#waitwait_div').html(waitwaitString);
	
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
		var error = null;
		var reservations = null;
		
		console.log("LoadData", json);
		
		// Kill the spinner.
		amcount--;
		if (amcount <= 0) {
		    $('#spinner').addClass("hidden");
		}
		if (json.code) {
		    console.log("Could not get reservation history for " +
				name + ": " + json.value);
		    $('#' + name + " .res-error").html(json.value);
		    $('#' + name + " .res-error").removeClass("hidden");
		    $('#' + name).removeClass("hidden");
		    return;
		}
		reservations = json.value.reservations;
		rescount += reservations.length;
		
		if (reservations.length == 0) {
		    if (amcount == 0 && rescount == 0) {
			// No reservations at all, show the message.
			$('#noreservations').removeClass("hidden");
		    }
		    return;
		}

		// Generate the main template.
		var html = listTemplate({
		    "reservations" : reservations,
		    "showcontrols" : false,
		    "showproject"  : true,
		    "showactivity" : false,
		    "showuser"     : (window.UID !== undefined ? false : true),
		    "showusing"    : false,
		    "showstatus"   : false,
		    "name"         : name,
		    "isadmin"      : window.ISADMIN,
		    "error"        : error,
		});
		$('#' + name + " .panel-body").html(html);

		// On error, no need for the rest of this.
		if (error)
		    return;

		// Check for history.
		_.each(reservations, function(value, uuid) {
		    var id = '#' + name +
			' tr[data-uuid="' + uuid + '"] ';

		    if (_.has(value, 'history') && value.history.length) {
			$(id + " .resgraph-button").removeClass("invisible");

			// Bind usage history graph.
			$(id + ' .resgraph-button').click(function() {
			    DrawHistoryGraph(value);
			    return false;
			});
		    }
		});

		// Format dates with moment before display.
		$('#' + name + ' .format-date').each(function() {
		    var date = $.trim($(this).html());
		    if (date != "") {
			$(this).html(moment(date).format("lll"));
		    }
		});
		$('#' + name + ' .tablesorter')
		    .tablesorter({
			theme : 'bootstrap',
			widgets : [ "uitheme", "zebra"],
			headerTemplate : '{content} {icon}',
		    });
		// This activates the tooltip subsystem.
		$('[data-toggle="tooltip"]').tooltip({
		    delay: {"hide" : 250, "show" : 250},
		    placement: 'auto',
		});
		// This activates the popover subsystem.
		$('[data-toggle="popover"]').popover({
		    placement: 'auto',
		    container: 'body',
		});
		$('#' + name).removeClass("hidden");
	    }
	    var args = {"cluster" : name};
	    if (window.UID !== undefined) {
		args["uid"] = window.UID;
	    }
	    else {
		args["pid"] = window.PID;
	    }
	    var xmlthing = sup.CallServerMethod(null, "reserve",
						"ReservationHistory", args);

	    xmlthing.done(callback);
	});
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
    // Helper.
    function decodejson(id) {
	return JSON.parse(_.unescape($(id)[0].textContent));
    }
    $(document).ready(initialize);
});


