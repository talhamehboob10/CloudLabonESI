$(function ()
{
    'use strict';
    var templates      = APT_OPTIONS.fetchTemplateList(['aggregate-status',
				       'waitwait-modal', 'oops-modal']);
    var template       = _.template(templates['aggregate-status']);
    var waitwait       = templates['waitwait-modal'];
    var oops           = templates['oops-modal'];
    
    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);

	$('#waitwait_div').html(waitwait);
	$('#oops_div').html(oops);
	LoadStatus();
    }

    function LoadStatus(earliest)
    {
	var callback = function(json) {
	    console.log(json);
	    if (json.code) {
		console.log("Could not get status data: " + json.value);
		return;
	    }
	    RenderPage(json.value);
	};
	var args = null;
	var xmlthing = sup.CallServerMethod(null, "aggregate-status",
					    "AggregateStatus", args);
	xmlthing.done(callback);
    }

    var flagshelp =
	"<table class='table table-condensed table-bordered'>" +
	" <tr><td>D</td><td>Disabled</td></tr>" +
	" <tr><td>A</td><td>Admin only</td></tr>" +
	" <tr><td>R</td><td>Reservations</td></tr>" +
	" <tr><td>d</td><td>Datasets</td></tr>" +
	" <tr><td>M</td><td>Monitored</td></tr>" +
	" <tr><td>I</td><td>No Local Images</td></tr>" +
	" <tr><td>P</td><td>Prestage Images</td></tr>" +
	" <tr><td>E</td><td>Saved Max Extensions</td></tr>" +
	"</table>";

    function RenderPage(status)
    {
	_.each(status, function(value, key) {
	    // Generate a "flags" string.
	    var flags = "";
	    flags += (value.disabled      ? "D" : "-");
	    flags += (value.adminonly     ? "A" : "-");
	    flags += (value.reservations  ? "R" : "-");
	    flags += (value.datasets      ? "d" : "-");
	    flags += (value.monitor       ? "M" : "-");
	    flags += (value.nolocalimages ? "I" : "-");
	    flags += (value.prestageimages ? "P" : "-");
	    flags += (value.precalcmaxext ? "E" : "-");
	    value.flags = flags;

	    // Ratio
	    if (value.pcount) {
		var pcount = parseInt(value.pcount);
		var pfree  = parseInt(value.pfree);
		value.ratio = Math.round(((pcount - pfree) / pcount) * 100)
		value.ratio = "" + value.ratio + "%";
	    }
	    else {
		value.ratio = "0%";
	    }
	});
	
	var html = template({"status"   : status,
			     "isadmin"  : window.ISADMIN,
			     "isfadmin" : window.ISFADMIN});
	$('#page-body').html(html);
	    
	// Format dates with moment before display.
	$('.format-date').each(function() {
	    var date = $.trim($(this).html());
	    if (date != "") {
		$(this).html(moment($(this).html())
			     .format("ddd MMM D h:mm A"));
	    }
	});
	$('.table-status')
	    .tablesorter({
		theme : 'bootstrap',
		widgets: ["uitheme", "zebra", "resizable"],
		headerTemplate : '{content} {icon}',

		headers: {
		    0: {
			sorter : "text",
		    }
		},
		sortList: [[1,1],[0,0]],
	    });
	
	$('#flags-help').attr('data-content', flagshelp);
	$('[data-toggle="popover"]').popover({
	    placement: 'auto',
	    html: true,
	});
	$('[data-toggle="tooltip"]').tooltip({
	    placement: 'auto',
	});
    }
    
    $(document).ready(initialize);
});
