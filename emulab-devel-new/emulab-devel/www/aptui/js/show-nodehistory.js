$(function ()
{
    'use strict';

    var templates = APT_OPTIONS.fetchTemplateList(['show-nodehistory',
						   'nodehistory-list',
						   'oops-modal',
						   'waitwait-modal']);
    var mainTemplate = _.template(templates['show-nodehistory']);
    var listTemplate = _.template(templates['nodehistory-list']);
    var reverse        = true;
    var alloconly      = true;
    var min            = null;  // Lowest record index on the page
    var max            = null;  // Highest record index on the page

    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);

	var html = mainTemplate({});
	$('#main-body').html(html);

	// Now we can do this.
	$('#oops_div').html(templates['oops-modal']);
	$('#waitwait_div').html(templates['waitwait-modal']);
	
	if (window.TARGET !== undefined) {
	    $('#main-body .fornode')
		.html("for " + window.TARGET)
		.removeClass("hidden");
	}
	$('.next-button').click(function (event) {
	    event.preventDefault();
	    LoadHistory("next");
	});
	$('#allocated-only, #reverse-order').change(function (event) {
	    ChangeMode(event.target);
	});
	$('#start-date-button').click(function (event) {
	    StartAtDate();
	});
	$('#start-search-button').click(function (event) {
	    Search();
	});
	
	LoadHistory(null);
    }

    // Use "null" for direction to keep from changing the page.
    function LoadHistory(direction, args)
    {
	var callback = function(json) {
	    console.log(json);
	    if (json.code) {
		console.log("Could not get history data: " + json.value);
		return;
	    }
	    // Remember bounds on new page, for nex/prev buttons
	    min = json.value.min;
	    max = json.value.max;
	    if (_.has(args, "TARGET")) {
		window.TARGET = args["TARGET"];
		$('#main-body .fornode')
		    .html("for " + window.TARGET)
		    .removeClass("hidden");
	    }
	    RenderHistory(json.value.entries);
	};
	$('#nodehistory-table-div').addClass("hidden");
	$('#main-body .control-buttons').addClass("hidden");
	$('#main-body .spinning').removeClass("hidden");

	if (args === undefined) {
	    args = {};
	}
	args["reverse"]   = (reverse ? 1 : 0);
	args["alloconly"] = (alloconly ? 1 : 0);

	if (min != null && max != null) {
	    args["min"] = min;
	    args["max"] = max;
	    if (direction != null) {
		args["direction"] = direction;
	    }
	}
	// Add this unless we are searching.
	if (!_.has(args, "TARGET") && window.TARGET !== undefined) {
	    args["TARGET"] = window.TARGET;
	}
	console.info(args);
	var xmlthing = sup.CallServerMethod(null, "node", "GetHistory", args);
	xmlthing.done(callback);
    }

    function RenderHistory(history)
    {
	var html = listTemplate({"history"    : history,
				 "shownodeid" : (window.TARGET !== undefined
						 ? false : true),
				});
	$('#main-body .spinning').addClass("hidden");
	$('#nodehistory-table-div').removeClass("hidden");
	$('#nodehistory-table-div').html(html);
	$('#main-body .control-buttons').removeClass("hidden");

	// Format dates with moment before display.
	$('.format-date').each(function() {
	    var date = $.trim($(this).html());
	    if (date != "") {
		$(this).html(moment($(this).html())
			     .format("MM/DD/YY h:mm A"));
	    }
	});
	$('[data-toggle="popover"]').popover({
	    trigger: 'hover',
	    placement: 'auto',
	    html: true,
	});

	$('#history-table')
	    .tablesorter({
		theme : 'bootstrap',
		widgets : [ "uitheme", "zebra"],
		headerTemplate : '{content} {icon}',
	    });
    }

    // Change mode (checkboxes).
    function ChangeMode(target)
    {
	var  id = $(target).attr("id");
	var  checked = $(target).is(':checked');

	if (id == "allocated-only") {
	    alloconly = checked;
	}
	else if (id == "reverse-order") {
	    reverse = checked;
	}
	else {
	    console.info("ChangeMode oops: " + id);
	    return;
	}
	LoadHistory(null);
    }

    // Change search to start at a date.
    function StartAtDate()
    {
	var val = $('#start-date').val();
	console.info("StartAtDate: ", val);
	if (val == "") {
	    return;
	}
	var when = moment(val);
	if (! (when && when.isValid())) {
	    alert("Not a valid date");
	    return;
	}
	// Clear these, we will get new bounds.
	min = max = null;
	LoadHistory(null, {"startdate" : when.unix()});
    }

    // Search for a specific node or IP. We respect the date is there one.
    function Search()
    {
	var val = $('#search-node').val();
	if (val == "") {
	    return;
	}
	var args = {"TARGET" : val};

	// Pass through date.
	if ($('#start-date').val() != "") {
	    var when = moment($('#start-date').val());
	    if (! (when && when.isValid())) {
		alert("Not a valid date");
		return;
	    }
	    args["startdate"] = when.unix();
	    // Clear these, we will get new bounds.
	    min = max = null;
	}
	LoadHistory(null, args);
    }

    $(document).ready(initialize);
});
